/// 每日任务（Daily Quests）服务 — 见 f3.md §七
///
/// 任务定义（f3 §7.2）：
/// - Quest 1: 完成 1 个板块练习（+5）
/// - Quest 2: 清空复习队列（+5）
/// - Quest 3: 同一天完成 2 个不同板块（+10）
/// - 全部完成：+20 + 1 张冻结卡
library;

import '../constants/xp_rules.dart';
import '../data/storage_service.dart';
import 'xp_service.dart';

enum QuestEvent { sessionComplete, reviewCleared }

class DailyQuestService {
  DailyQuestService._();

  static final DailyQuestService instance = DailyQuestService._();

  StorageService get _storage => StorageService.instance;

  /// 各板块保存完成后调用（f3 §十）
  Future<void> updateDailyQuests(
    String userId,
    QuestEvent event, {
    String? board,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    await _storage.execute(
      'INSERT OR IGNORE INTO daily_quests (user_id, quest_date, created_at) '
      'VALUES (?, ?, ?)',
      [userId, today, DateTime.now().toIso8601String()],
    );

    switch (event) {
      case QuestEvent.sessionComplete:
        await _storage.execute(
          'UPDATE daily_quests SET quest_1_done = 1 '
          'WHERE user_id = ? AND quest_date = ? AND quest_1_done = 0',
          [userId, today],
        );
        await XpService.instance.awardXP(userId, XpSource.dailyQuest,
            amount: 5, board: board);
        if (await _distinctBoardCountToday(userId, today) >= 2) {
          await _storage.execute(
            'UPDATE daily_quests SET quest_3_done = 1 '
            'WHERE user_id = ? AND quest_date = ? AND quest_3_done = 0',
            [userId, today],
          );
          await XpService.instance.awardXP(userId, XpSource.dailyQuest,
              amount: 10, board: board);
        }
      case QuestEvent.reviewCleared:
        await _storage.execute(
          'UPDATE daily_quests SET quest_2_done = 1 '
          'WHERE user_id = ? AND quest_date = ? AND quest_2_done = 0',
          [userId, today],
        );
        await XpService.instance.awardXP(
          userId,
          XpSource.dailyQuest,
          amount: 5,
          board: 'review',
        );
    }

    await _checkAllCompleted(userId, today);
  }

  /// 今天完成了几个不同板块（跨 5 张 session 表 UNION，见 f3 §7.3）
  Future<int> _distinctBoardCountToday(String userId, String today) async {
    final rows = await _storage.query(
      'SELECT COUNT(*) as count FROM ('
      "SELECT 'vocab' as board FROM vocab_sessions WHERE user_id = ? AND date(created_at) = ? "
      "UNION SELECT 'listening' FROM listening_sessions WHERE user_id = ? AND date(created_at) = ? "
      "UNION SELECT 'reading' FROM reading_sessions WHERE user_id = ? AND date(created_at) = ? "
      "UNION SELECT 'speaking' FROM speaking_sessions WHERE user_id = ? AND date(created_at) = ? "
      "UNION SELECT 'writing' FROM writing_sessions WHERE user_id = ? AND date(created_at) = ?)",
      [userId, today, userId, today, userId, today, userId, today, userId, today],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> _checkAllCompleted(String userId, String today) async {
    final rows = await _storage.query(
      'SELECT quest_1_done, quest_2_done, quest_3_done, all_completed '
      'FROM daily_quests WHERE user_id = ? AND quest_date = ?',
      [userId, today],
    );
    if (rows.isEmpty) return;
    final r = rows.first;
    final allDone = (r['quest_1_done'] as int? ?? 0) == 1 &&
        (r['quest_2_done'] as int? ?? 0) == 1 &&
        (r['quest_3_done'] as int? ?? 0) == 1;
    final alreadyClaimed = (r['all_completed'] as int? ?? 0) == 1;
    if (allDone && !alreadyClaimed) {
      await _storage.execute(
        'UPDATE daily_quests SET all_completed = 1 WHERE user_id = ? AND quest_date = ?',
        [userId, today],
      );
      await XpService.instance
          .awardDefault(userId, XpSource.dailyQuestAll);
      // 奖励冻结卡（复用 StreakService 内部逻辑：直接写表，上限 3）
      await _storage.execute(
        'INSERT INTO streak_freezes (user_id, quantity) VALUES (?, 1) '
        'ON CONFLICT(user_id) DO UPDATE SET quantity = MIN(quantity + 1, 3)',
        [userId],
      );
    }
  }
}
