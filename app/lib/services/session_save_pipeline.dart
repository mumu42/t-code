/// 各板块统一保存管线 — 见 f5.md
///
/// 规约（f5 §一 / §六）：
/// 1. 每个板块只有一个 saveXxxSession() 入口，内部调用本管线
/// 2. session/response 落盘在 transaction() 中（要么全成要么全回滚）
/// 3. 级联调用固定顺序：XP → SRS 入队 → streak → 每日任务
///    （级联在事务外执行：XP/SRS 各有自己的写入，避免嵌套事务死锁）
/// 4. 不跨板块写数据：saveBoardSession / saveResponses 由各板块实现
/// 5. 幂等：同 session_id 重复保存直接跳过
library;

import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../constants/xp_rules.dart';
import '../data/storage_service.dart';
import 'daily_quest_service.dart';
import 'srs_service.dart';
import 'streak_service.dart';
import 'xp_service.dart';

/// 板块标识
enum Board { vocab, listening, reading, speaking, writing, review }

extension BoardDb on Board {
  String get dbValue => name;
}

/// 单题作答明细（各板块用 extra 扩展自有字段）
class SessionResponse {
  const SessionResponse({
    required this.itemId,
    required this.itemType,
    required this.correct,
    this.rating,
    this.responseTimeMs,
    this.grammarTags = const [],
    this.extra,
  });

  final String itemId;
  final String itemType;
  final bool correct;
  final int? rating; // 复习板块用（1-4）
  final int? responseTimeMs;
  final List<String> grammarTags;
  final Map<String, Object?>? extra;
}

/// 一次保存的上下文（f5 §二 SaveContext）
class SaveContext {
  const SaveContext({
    required this.userId,
    required this.board,
    required this.sessionId,
    required this.startedAt,
    required this.completedAt,
    required this.totalItems,
    required this.correctCount,
    required this.wrongCount,
    required this.accuracy,
    required this.timeSpentSec,
    required this.level,
    required this.responses,
    this.skippedCount = 0,
    this.metadata = const {},
  });

  final String userId;
  final Board board;
  final String sessionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final int totalItems;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final double accuracy;
  final int timeSpentSec;
  final String level; // 本次练习的 CEFR 锚点
  final List<SessionResponse> responses;
  final Map<String, Object?> metadata;
}

/// 保存结果（级联回执）
class SaveResult {
  const SaveResult({
    required this.sessionSaved,
    required this.xpAwarded,
    required this.srsEnrolled,
    required this.streakUpdated,
    required this.questsUpdated,
    required this.errors,
  });

  final bool sessionSaved;
  final int xpAwarded;
  final int srsEnrolled;
  final bool streakUpdated;
  final bool questsUpdated;
  final List<String> errors;

  static SaveResult get failed => const SaveResult(
        sessionSaved: false,
        xpAwarded: 0,
        srsEnrolled: 0,
        streakUpdated: false,
        questsUpdated: false,
        errors: [],
      );
}

/// 板块自定义的落盘实现（各 boards 目录下提供）
typedef BoardSessionWriter = Future<void> Function(
    DatabaseExecutor tx, SaveContext ctx);

/// 统一保存管线（f5 §二 executeSavePipeline）
///
/// [saveBoardSession] / [saveResponses] 由各板块实现，
/// 只写本板块的 session / response 表。
Future<SaveResult> executeSavePipeline(
  SaveContext ctx, {
  required BoardSessionWriter saveBoardSession,
  required BoardSessionWriter saveResponses,
}) async {
  final storage = StorageService.instance;
  final errors = <String>[];

  // 幂等检查：同 session_id 已存在则跳过（f5 §六.9）
  final existing = await storage.query(
    'SELECT id FROM ${ctx.board.dbValue}_sessions WHERE id = ?',
    [ctx.sessionId],
  );
  if (existing.isNotEmpty) {
    final skipped = SaveResult.failed;
    return SaveResult(
      sessionSaved: true,
      xpAwarded: 0,
      srsEnrolled: 0,
      streakUpdated: false,
      questsUpdated: false,
      errors: [...skipped.errors, 'session ${ctx.sessionId} 已保存，幂等跳过'],
    );
  }

  // 1-2. session 主表 + response 明细（同一事务）
  await storage.transaction((tx) async {
    await saveBoardSession(tx, ctx);
    await saveResponses(tx, ctx);
  });

  // 3. XP 奖励（含每题 +2/+1、板块完成 +10、连击 +5）
  var xpAwarded = 0;
  try {
    final xp = await XpService.instance.awardXP(
      ctx.userId,
      XpSource.sessionComplete,
      amount: _calculateSessionXp(ctx),
      board: ctx.board.dbValue,
      relatedId: ctx.sessionId,
    );
    xpAwarded = xp.gained;
  } catch (e) {
    errors.add('XP: $e');
  }

  // 4. SRS 入队（错题 + 新学项）
  var srsEnrolled = 0;
  try {
    for (final r in ctx.responses) {
      if (!r.correct || r.rating != null) {
        await SrsService.instance.enrollCard(
          ctx.userId,
          r.itemType,
          r.itemId,
          initialDifficulty: r.correct ? 5.0 : 7.0,
          initialStability: r.correct ? 1.0 : 0.5,
        );
        srsEnrolled++;
      }
    }
  } catch (e) {
    errors.add('SRS: $e');
  }

  // 5. Streak 更新
  var streakUpdated = false;
  try {
    final streak = await StreakService.instance.updateStreak(ctx.userId);
    streakUpdated = streak.changed;
  } catch (e) {
    errors.add('Streak: $e');
  }

  // 6. 每日任务
  var questsUpdated = false;
  try {
    await DailyQuestService.instance
        .updateDailyQuests(ctx.userId, QuestEvent.sessionComplete,
            board: ctx.board.dbValue);
    questsUpdated = true;
  } catch (e) {
    errors.add('Quests: $e');
  }

  return SaveResult(
    sessionSaved: true,
    xpAwarded: xpAwarded,
    srsEnrolled: srsEnrolled,
    streakUpdated: streakUpdated,
    questsUpdated: questsUpdated,
    errors: errors,
  );
}

/// f5 §二 calculateSessionXp：每题正确 +2 / 错误 +1 + 板块完成 +10 + 连击 +5
int _calculateSessionXp(SaveContext ctx) {
  var xp = 0;
  for (final r in ctx.responses) {
    xp += r.correct ? 2 : 1;
  }
  xp += XpSource.sessionComplete.defaultAmount;
  var consecutiveCorrect = 0;
  for (final r in ctx.responses) {
    if (r.correct) {
      consecutiveCorrect++;
    } else {
      consecutiveCorrect = 0;
    }
  }
  if (consecutiveCorrect >= 5) xp += XpSource.combo.defaultAmount;
  return xp;
}

/// 板块 session id 生成：board_timestamp_random（f5 §六.4）
String generateSessionId(Board board) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rand = DateTime.now().microsecondsSinceEpoch % 100000;
  return '${board.dbValue}_${ts}_$rand';
}

/// 当前难度锚点（所有 assemble 前必须调用，'B1' 兜底 — f1 §5.1）
Future<String> getCurrentLevel([String userId = kLocalUserId]) async {
  final rows = await StorageService.instance.query(
    'SELECT current_level FROM user_profile WHERE user_id = ?',
    [userId],
  );
  return (rows.first['current_level'] as String?) ?? 'B1';
}
