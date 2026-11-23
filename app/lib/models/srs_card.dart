/// SRS 复习卡片模型 — 见 f4.md §三
library;

/// 复习反馈档位（f4 §3.1：1=again / 2=hard / 3=good / 4=easy）
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Rating(this.value);
  final int value;

  static Rating fromValue(int v) =>
      Rating.values.firstWhere((r) => r.value == v);
}

/// 卡片状态机（f4 §3.4）
enum CardState {
  newCard('new'),
  learning('learning'),
  review('review'),
  relearning('relearning');

  const CardState(this.dbValue);
  final String dbValue;

  static CardState fromDb(String v) => CardState.values
      .firstWhere((s) => s.dbValue == v, orElse: () => CardState.newCard);
}

/// srs_cards 表的一行
class SrsCard {
  SrsCard({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.itemId,
    required this.difficulty,
    required this.stability,
    this.retrievability = 1.0,
    required this.state,
    this.step = 0,
    this.intervalDays = 0,
    required this.dueDate,
    this.lastReviewedAt,
    this.reviewCount = 0,
    this.lapseCount = 0,
    this.totalTimeSpent = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String userId;
  final String itemType; // 'vocab' / 'grammar' / 'sentence' / 'collocation'
  final String itemId;
  final double difficulty; // 1-10，越高越难记
  final double stability; // 记忆稳定性（天）
  final double retrievability;
  final CardState state;
  final int step;
  final int intervalDays;
  final DateTime dueDate;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final int lapseCount;
  final int totalTimeSpent;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SrsCard.fromMap(Map<String, Object?> map) => SrsCard(
        id: map['id']! as int,
        userId: map['user_id']! as String,
        itemType: map['item_type']! as String,
        itemId: map['item_id']! as String,
        difficulty: (map['difficulty']! as num).toDouble(),
        stability: (map['stability']! as num).toDouble(),
        retrievability: (map['retrievability'] as num?)?.toDouble() ?? 1.0,
        state: CardState.fromDb(map['state']! as String),
        step: (map['step'] as int?) ?? 0,
        intervalDays: (map['interval_days'] as int?) ?? 0,
        dueDate: DateTime.parse(map['due_date']! as String),
        lastReviewedAt: map['last_reviewed_at'] == null
            ? null
            : DateTime.parse(map['last_reviewed_at']! as String),
        reviewCount: (map['review_count'] as int?) ?? 0,
        lapseCount: (map['lapse_count'] as int?) ?? 0,
        totalTimeSpent: (map['total_time_spent'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

/// calculateNextReview 的计算结果（不落库的纯数据）
class ReviewResult {
  const ReviewResult({
    required this.difficulty,
    required this.stability,
    required this.intervalDays,
    required this.dueDate,
    required this.newState,
    required this.newStep,
  });

  final double difficulty;
  final double stability;
  final int intervalDays;
  final DateTime dueDate;
  final CardState newState;
  final int newStep;
}
