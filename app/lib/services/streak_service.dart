/// Streak（连续学习天数）服务 — 见 f3.md §六
///
/// 冻结卡规则（f3 §6.2）：
/// - 连续 7 天奖励 1 张，上限 3 张
/// - streak 断了（昨天没练）自动消耗，不支持手动使用
library;

import '../constants/xp_rules.dart';
import '../data/storage_service.dart';
import 'xp_service.dart';

class StreakResult {
  const StreakResult({
    required this.streak,
    required this.changed,
    required this.reason,
  });

  final int streak;
  final bool changed;
  final StreakReason reason;
}

enum StreakReason { firstDay, continued, alreadyCounted, freezeUsed, broken }

class StreakService {
  StreakService._();

  static final StreakService instance = StreakService._();

  StorageService get _storage => StorageService.instance;

  /// 每次练习完成（updateGlobalProgress）后调用 — f3 §6.3
  Future<StreakResult> updateStreak(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await _storage.query(
      'SELECT streak_days, last_active_date FROM user_profile WHERE user_id = ?',
      [userId],
    );
    if (rows.isEmpty) {
      return const StreakResult(
          streak: 0, changed: false, reason: StreakReason.alreadyCounted);
    }

    final streakDays = (rows.first['streak_days'] as int?) ?? 0;
    final lastDate = rows.first['last_active_date'] as String?;

    var newStreak = streakDays;
    var changed = false;
    var reason = StreakReason.alreadyCounted;

    if (lastDate == null) {
      newStreak = 1;
      changed = true;
      reason = StreakReason.firstDay;
    } else if (lastDate == today) {
      reason = StreakReason.alreadyCounted;
    } else {
      final diffDays = DateTime.parse(today)
          .difference(DateTime.parse(lastDate))
          .inDays;
      if (diffDays == 1) {
        newStreak += 1;
        changed = true;
        reason = StreakReason.continued;
      } else if (diffDays > 1) {
        final freeze = await _getFreezeQuantity(userId);
        if (freeze > 0) {
          await _consumeFreeze(userId);
          newStreak = 1;
          changed = true;
          reason = StreakReason.freezeUsed;
        } else {
          newStreak = 1;
          changed = true;
          reason = StreakReason.broken;
        }
      }
    }

    if (changed) {
      await _storage.execute(
        'UPDATE user_profile SET streak_days = ?, last_active_date = ? '
        'WHERE user_id = ?',
        [newStreak, today, userId],
      );
      await _storage.execute(
        'INSERT OR IGNORE INTO streak_log (user_id, date, sessions_count, created_at) '
        'VALUES (?, ?, 1, ?)',
        [userId, today, DateTime.now().toIso8601String()],
      );
      // 每 7 天：奖励冻结卡 + 30 XP（XP 由 XpService 内部处理每日上限）
      if (newStreak > 0 && newStreak % 7 == 0) {
        await _awardFreeze(userId);
        await XpService.instance.awardDefault(
          userId,
          XpSource.streakBonus,
          relatedId: '$newStreak',
        );
      }
    }

    return StreakResult(
        streak: newStreak, changed: changed, reason: reason);
  }

  Future<int> _getFreezeQuantity(String userId) async {
    final rows = await _storage.query(
      'SELECT quantity FROM streak_freezes WHERE user_id = ?',
      [userId],
    );
    return rows.isEmpty ? 0 : (rows.first['quantity'] as int?) ?? 0;
  }

  /// 获得冻结卡（上限 3）
  Future<void> _awardFreeze(String userId) async {
    await _storage.execute(
      'INSERT INTO streak_freezes (user_id, quantity, last_awarded_at) '
      'VALUES (?, 1, ?) ON CONFLICT(user_id) DO UPDATE SET '
      'quantity = MIN(quantity + 1, 3), last_awarded_at = excluded.last_awarded_at',
      [userId, DateTime.now().toIso8601String()],
    );
  }

  Future<void> _consumeFreeze(String userId) async {
    await _storage.execute(
      'UPDATE streak_freezes SET quantity = quantity - 1 '
      'WHERE user_id = ? AND quantity > 0',
      [userId],
    );
  }
}
