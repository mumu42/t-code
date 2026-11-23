/// SRS 复习引擎 — 简化版 FSRS，见 f4.md
///
/// 规约（f4 §十）：
/// - 4 档 rating；again 永远回 learning/relearning（分钟级）
/// - 复习间隔上限 365 天，下限 1 天（review 状态）
/// - 每次 submitReview 必须写 srs_reviews 流水（含前后参数快照）
/// - 入队用 enrollCard（INSERT OR IGNORE 防重复）
/// - V2 升级路径：完整 FSRS-4.5 + 遗忘曲线 R = exp(-t/S)
library;

import '../constants/app_constants.dart';
import '../constants/xp_rules.dart';
import '../data/storage_service.dart';
import '../models/srs_card.dart';
import 'xp_service.dart';

/// Learning 阶段步数（分钟）— f4 §3.2
const List<int> kLearningSteps = [1, 10];

/// Relearning 阶段步数（分钟）
const List<int> kRelearningSteps = [10];

/// 各 rating 对 difficulty / stability / interval 的影响系数
const Map<Rating, ({double difficulty, double stability, double interval})>
    kRatingModifiers = {
  Rating.again: (difficulty: 1.5, stability: 0.0, interval: 0.0),
  Rating.hard: (difficulty: 0.5, stability: 0.8, interval: 0.8),
  Rating.good: (difficulty: -0.2, stability: 1.0, interval: 1.0),
  Rating.easy: (difficulty: -0.5, stability: 1.3, interval: 1.5),
};

/// 各板块入队时的初始难度参考 — f4 §6.8
const Map<String, double> kItemTypeDefaultDifficulty = {
  'vocab': 5.0,
  'sentence': 5.0, // 听力/口语句；阅读长难句由调用方传 6.0
  'collocation': 4.5,
  'grammar': 7.0, // 语法错题初始更难
};

class SrsService {
  SrsService._();

  static final SrsService instance = SrsService._();

  StorageService get _storage => StorageService.instance;

  // ──────────────────────────────────────────────────────────
  // 核心算法（纯函数，可单测）
  // ──────────────────────────────────────────────────────────

  /// 计算下一次复习参数 — f4 §3.3，覆盖 4 rating × 4 state 全部组合
  ReviewResult calculateNextReview(SrsCard card, Rating rating) {
    final mod = kRatingModifiers[rating]!;
    final now = DateTime.now();

    // ── 更新 difficulty（clamp 1-10）──
    var newDifficulty = card.difficulty + mod.difficulty;
    newDifficulty = newDifficulty.clamp(1.0, 10.0);

    // ── 更新 stability ──
    double newStability;
    if (rating == Rating.again) {
      newStability = 0.1; // 遗忘 → 稳定性归零
    } else {
      final goodBonus = 1 + (card.reviewCount / 10); // 复习次数越多越稳
      newStability = card.stability * mod.stability * goodBonus;
      newStability = newStability < 0.1 ? 0.1 : newStability;
    }

    // ── 计算间隔与新状态 ──
    int intervalDays;
    var newState = card.state;
    var newStep = card.step;

    switch (card.state) {
      case CardState.newCard:
        if (rating == Rating.again) {
          intervalDays = 0;
          newState = CardState.learning;
          newStep = 0;
        } else {
          intervalDays = rating == Rating.hard ? 1 : rating == Rating.good ? 1 : 3;
          newState = CardState.review;
          newStep = 0;
        }
      case CardState.learning:
        if (rating == Rating.again) {
          newStep = 0;
          intervalDays = 0;
        } else if (rating.value >= 3) {
          newState = CardState.review;
          intervalDays = 1;
          newStep = 0;
        } else {
          newStep = (card.step + 1).clamp(0, kLearningSteps.length - 1);
          intervalDays = 0;
        }
      case CardState.review:
        if (rating == Rating.again) {
          newState = CardState.relearning;
          newStep = 0;
          intervalDays = 0; // 10 分钟后
        } else {
          intervalDays = (newStability * mod.interval).round();
          intervalDays = intervalDays.clamp(1, 365); // clamp 1-365 天
        }
      case CardState.relearning:
        if (rating == Rating.again) {
          newStep = 0;
          intervalDays = 0;
        } else if (rating.value >= 3) {
          newState = CardState.review;
          intervalDays = 1;
          newStep = 0;
        } else {
          newStep = (card.step + 1).clamp(0, kRelearningSteps.length - 1);
          intervalDays = 0;
        }
    }

    // ── 计算 due_date（分钟级 or 天级）──
    DateTime dueDate;
    if (intervalDays == 0 &&
        (newState == CardState.learning || newState == CardState.relearning)) {
      final steps =
          newState == CardState.learning ? kLearningSteps : kRelearningSteps;
      final minutes = steps[newStep.clamp(0, steps.length - 1)];
      dueDate = now.add(Duration(minutes: minutes));
    } else {
      dueDate = now.add(Duration(days: intervalDays));
    }

    return ReviewResult(
      difficulty: newDifficulty,
      stability: newStability,
      intervalDays: intervalDays,
      dueDate: dueDate,
      newState: newState,
      newStep: newStep,
    );
  }

  /// 间隔预览（Rating 按钮下方文案）— f4 §7.4
  String getIntervalPreview(SrsCard card, Rating rating) {
    final result = calculateNextReview(card, rating);
    if (result.intervalDays == 0) {
      const steps = kLearningSteps;
      final minutes =
          steps[result.newStep.clamp(0, steps.length - 1)];
      return minutes < 60 ? '< ${minutes}m' : '~${minutes ~/ 60}h';
    }
    if (result.intervalDays == 1) return '~1d';
    if (result.intervalDays < 30) return '~${result.intervalDays}d';
    return '~${(result.intervalDays / 30).round()}mo';
  }

  // ──────────────────────────────────────────────────────────
  // 入队（各板块统一入口）— f4 §6.1
  // ──────────────────────────────────────────────────────────

  /// 将一个学习项加入 SRS（INSERT OR IGNORE 防重复，幂等）
  Future<void> enrollCard(
    String userId,
    String itemType,
    String itemId, {
    double? initialDifficulty,
    double initialStability = 1.0,
  }) async {
    final difficulty =
        initialDifficulty ?? kItemTypeDefaultDifficulty[itemType] ?? 5.0;
    final now = DateTime.now().toIso8601String();
    await _storage.execute(
      'INSERT OR IGNORE INTO srs_cards '
      '(user_id, item_type, item_id, difficulty, stability, state, due_date, '
      ' created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, itemType, itemId, difficulty, initialStability,
          'new', now, now, now],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 查询 — f4 §五
  // ──────────────────────────────────────────────────────────

  /// 今日到期卡（排序：relearning > learning > review，同级 due_date ASC）
  Future<List<SrsCard>> getDueCards(
    String userId, {
    int limit = kReviewSessionDueLimit,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _storage.query(
      'SELECT * FROM srs_cards WHERE user_id = ? AND due_date <= ? '
      "AND state != 'new' ORDER BY CASE state "
      "WHEN 'relearning' THEN 0 WHEN 'learning' THEN 1 WHEN 'review' THEN 2 END, "
      'due_date ASC LIMIT ?',
      [userId, now, limit],
    );
    return rows.map(SrsCard.fromMap).toList();
  }

  /// 新卡（state='new'）
  Future<List<SrsCard>> getNewCards(
    String userId, {
    int limit = kReviewSessionNewLimit,
  }) async {
    final rows = await _storage.query(
      "SELECT * FROM srs_cards WHERE user_id = ? AND state = 'new' "
      'ORDER BY created_at ASC LIMIT ?',
      [userId, limit],
    );
    return rows.map(SrsCard.fromMap).toList();
  }

  /// 到期数量（首页角标用）
  Future<int> getDueCount(String userId) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _storage.query(
      "SELECT COUNT(*) as count FROM srs_cards "
      "WHERE user_id = ? AND due_date <= ? AND state != 'new'",
      [userId, now],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  // ──────────────────────────────────────────────────────────
  // 提交复习 — f4 §四（事务：更新卡片 + 写流水；XP 在事务外）
  // ──────────────────────────────────────────────────────────

  Future<void> submitReview(
    String userId,
    int cardId,
    Rating rating, {
    int? responseTimeMs,
  }) async {
    final rows = await _storage
        .query('SELECT * FROM srs_cards WHERE id = ?', [cardId]);
    if (rows.isEmpty) throw StateError('Card $cardId not found');
    final card = SrsCard.fromMap(rows.first);

    final before = (
      difficulty: card.difficulty,
      stability: card.stability,
      interval: card.intervalDays,
    );
    final result = calculateNextReview(card, rating);
    final now = DateTime.now().toIso8601String();

    await _storage.transaction((tx) async {
      await tx.execute(
        'UPDATE srs_cards SET difficulty = ?, stability = ?, retrievability = 1.0, '
        'state = ?, step = ?, interval_days = ?, due_date = ?, '
        'last_reviewed_at = ?, review_count = review_count + 1, '
        'lapse_count = lapse_count + ?, updated_at = ? WHERE id = ?',
        [
          result.difficulty,
          result.stability,
          result.newState.dbValue,
          result.newStep,
          result.intervalDays,
          result.dueDate.toIso8601String(),
          now,
          rating == Rating.again ? 1 : 0,
          now,
          cardId,
        ],
      );
      await tx.execute(
        'INSERT INTO srs_reviews (user_id, card_id, item_type, item_id, rating, '
        'response_time_ms, difficulty_before, stability_before, interval_before, '
        'difficulty_after, stability_after, interval_after, reviewed_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          userId, cardId, card.itemType, card.itemId, rating.value,
          responseTimeMs, before.difficulty, before.stability, before.interval,
          result.difficulty, result.stability, result.intervalDays, now,
        ],
      );
    });

    // XP 奖励（在事务外，awardXP 有自己的写入）— f4 §4.1 步骤 5
    if (rating.value >= 3) {
      await XpService.instance.awardXP(
        userId,
        XpSource.reviewCorrect,
        board: card.itemType,
        relatedId: card.itemId,
      );
    } else if (rating == Rating.hard) {
      await XpService.instance.awardXP(
        userId,
        XpSource.reviewHard,
        board: card.itemType,
        relatedId: card.itemId,
      );
    }
    // rating == again：不奖 XP
  }
}
