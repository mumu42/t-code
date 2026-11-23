/// XP 积分服务 — 见 f3.md §四
///
/// 规约（f3 §十一）：
/// - 每得 1 分必须写入 xp_log（流水审计）
/// - 每日上限 150 XP，在 awardXP() 中校验
/// - 升级检测在 awardXP() 返回中标记 leveledUp，由调用方决定是否展示
/// - 激励层与定级模块（CEFR）独立，不互相覆盖
library;

import '../constants/levels.dart';
import '../constants/xp_rules.dart';
import '../data/storage_service.dart';

class AwardResult {
  const AwardResult({
    required this.totalXp,
    required this.gained,
    required this.leveledUp,
    this.newLevel,
    this.previousLevelIndex,
  });

  final int totalXp;
  final int gained; // 本次实际获得（可能被上限截断 / 降为 0）
  final bool leveledUp;
  final LevelDef? newLevel;
  final int? previousLevelIndex;
}

class XpService {
  XpService._();

  static final XpService instance = XpService._();

  StorageService get _storage => StorageService.instance;

  /// 按 source 的默认数额发放
  Future<AwardResult> awardDefault(
    String userId,
    XpSource source, {
    String? board,
    String? relatedId,
  }) =>
      awardXP(userId, source, board: board, relatedId: relatedId);

  /// 发放 XP：查上限 → 写流水 → 更新总 XP → 检查升级
  Future<AwardResult> awardXP(
    String userId,
    XpSource source, {
    int? amount,
    String? board,
    String? relatedId,
  }) async {
    final requested = amount ?? source.defaultAmount;

    // 1. 检查每日上限
    final today = DateTime.now().toIso8601String().split('T').first;
    final todayRows = await _storage.query(
      'SELECT COALESCE(SUM(amount), 0) as total FROM xp_log '
      'WHERE user_id = ? AND date(created_at) = ?',
      [userId, today],
    );
    final usedToday = (todayRows.first['total'] as int?) ?? 0;
    final actualAmount =
        requested.clamp(0, kDailyXpCap - usedToday);

    if (actualAmount <= 0) {
      final totalXp = await _getTotalXp(userId);
      return AwardResult(totalXp: totalXp, gained: 0, leveledUp: false);
    }

    // 2. 写流水
    await _storage.execute(
      'INSERT INTO xp_log (user_id, source, amount, board, related_id, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        userId,
        source.logTag,
        actualAmount,
        board,
        relatedId,
        DateTime.now().toIso8601String(),
      ],
    );

    // 3. 更新总 XP
    await _storage.execute(
      'UPDATE user_profile SET total_xp = total_xp + ? WHERE user_id = ?',
      [actualAmount, userId],
    );

    // 4. 检查升级
    final profile = await _storage.query(
      'SELECT total_xp, current_level_index FROM user_profile WHERE user_id = ?',
      [userId],
    );
    final totalXp = (profile.first['total_xp'] as int?) ?? 0;
    final oldIdx = (profile.first['current_level_index'] as int?) ?? 0;
    final newIdx = calculateLevelIndex(totalXp);

    if (newIdx > oldIdx) {
      await _storage.execute(
        'UPDATE user_profile SET current_level_index = ? WHERE user_id = ?',
        [newIdx, userId],
      );
      await _storage.execute(
        'INSERT OR IGNORE INTO level_unlocks (user_id, level_index, unlocked_at) '
        'VALUES (?, ?, ?)',
        [userId, newIdx, DateTime.now().toIso8601String()],
      );
      return AwardResult(
        totalXp: totalXp,
        gained: actualAmount,
        leveledUp: true,
        newLevel: kLevels[newIdx],
        previousLevelIndex: oldIdx,
      );
    }

    return AwardResult(totalXp: totalXp, gained: actualAmount, leveledUp: false);
  }

  Future<int> _getTotalXp(String userId) async {
    final rows = await _storage.query(
      'SELECT total_xp FROM user_profile WHERE user_id = ?',
      [userId],
    );
    return (rows.first['total_xp'] as int?) ?? 0;
  }

  /// 累计 XP → 等级下标（0-11）
  static int calculateLevelIndex(int totalXp) {
    for (var i = kXpThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= kXpThresholds[i]) return i;
    }
    return 0;
  }

  /// 距下一级进度（首页 XPBar 用）
  static ({int current, int next, double progress}) getXPForNextLevel(
    int totalXp,
  ) {
    final idx = calculateLevelIndex(totalXp);
    final current = kXpThresholds[idx];
    final next = idx < kXpThresholds.length - 1
        ? kXpThresholds[idx + 1]
        : kXpThresholds[idx];
    final progress = next > current ? (totalXp - current) / (next - current) : 1.0;
    return (current: current, next: next, progress: progress);
  }

  /// 未查看的升级记录（首页 banner 用）
  Future<List<LevelDef>> getUnviewedLevelUps(String userId) async {
    final rows = await _storage.query(
      'SELECT level_index FROM level_unlocks '
      'WHERE user_id = ? AND viewed = 0 ORDER BY level_index ASC',
      [userId],
    );
    return rows
        .map((r) => kLevels[r['level_index'] as int])
        .toList();
  }

  /// 标记升级记录已查看
  Future<void> markLevelUpsViewed(String userId) async {
    await _storage.execute(
      'UPDATE level_unlocks SET viewed = 1 WHERE user_id = ? AND viewed = 0',
      [userId],
    );
  }

  /// 读取用户档案（等级 / XP / streak 等，首页展示用）
  Future<Map<String, Object?>?> getProfile(String userId) async {
    final rows = await _storage.query(
      'SELECT * FROM user_profile WHERE user_id = ?',
      [userId],
    );
    return rows.isEmpty ? null : rows.first;
  }
}
