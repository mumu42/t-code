import 'package:flutter_test/flutter_test.dart';
import 'package:linguaflow/models/srs_card.dart';
import 'package:linguaflow/services/srs_service.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final srs = SrsService.instance;

  SrsCard card({
    CardState state = CardState.newCard,
    double difficulty = 5.0,
    double stability = 1.0,
    int step = 0,
    int reviewCount = 0,
  }) =>
      SrsCard(
        id: 1,
        userId: 'local',
        itemType: 'vocab',
        itemId: 'w_001',
        difficulty: difficulty,
        stability: stability,
        state: state,
        step: step,
        intervalDays: 0,
        dueDate: now,
        reviewCount: reviewCount,
        createdAt: now,
        updatedAt: now,
      );

  group('calculateNextReview — 4 rating × 4 state 全组合（f4 §3.3）', () {
    test('new + again → learning，分钟级 due', () {
      final before = DateTime.now();
      final r = srs.calculateNextReview(card(), Rating.again);
      final after = DateTime.now();
      expect(r.newState, CardState.learning);
      expect(r.intervalDays, 0);
      // due 在 [before+30s, after+10min] 区间内（分钟级调度）
      expect(r.dueDate.isAfter(before.add(const Duration(seconds: 30))), isTrue);
      expect(r.dueDate.isBefore(after.add(const Duration(minutes: 11))), isTrue);
      expect(r.difficulty, closeTo(6.5, 0.01)); // 5.0 + 1.5
      expect(r.stability, closeTo(0.1, 0.001)); // 遗忘归零
    });

    test('new + good → review，间隔 1 天', () {
      final r = srs.calculateNextReview(card(), Rating.good);
      expect(r.newState, CardState.review);
      expect(r.intervalDays, 1);
    });

    test('new + easy → review，间隔 3 天', () {
      final r = srs.calculateNextReview(card(), Rating.easy);
      expect(r.newState, CardState.review);
      expect(r.intervalDays, 3);
    });

    test('learning + good → 毕业 review，间隔 1 天', () {
      final r = srs.calculateNextReview(
          card(state: CardState.learning), Rating.good);
      expect(r.newState, CardState.review);
      expect(r.intervalDays, 1);
    });

    test('learning + hard → 步数 +1，分钟级', () {
      final r = srs.calculateNextReview(
          card(state: CardState.learning, step: 0), Rating.hard);
      expect(r.newState, CardState.learning);
      expect(r.newStep, 1);
      expect(r.intervalDays, 0);
    });

    test('review + again → relearning', () {
      final r = srs.calculateNextReview(
          card(state: CardState.review), Rating.again);
      expect(r.newState, CardState.relearning);
      expect(r.intervalDays, 0);
    });

    test('review + good → 间隔 = stability × 1.0 × goodBonus', () {
      final r = srs.calculateNextReview(
        card(state: CardState.review, stability: 10.0, reviewCount: 0),
        Rating.good,
      );
      // goodBonus = 1 + 0/10 = 1.0；interval = 10.0 * 1.0 * 1.0 = 10
      expect(r.newState, CardState.review);
      expect(r.intervalDays, 10);
    });

    test('review 间隔 clamp 在 1-365 天', () {
      final tiny = srs.calculateNextReview(
          card(state: CardState.review, stability: 0.2), Rating.good);
      expect(tiny.intervalDays, greaterThanOrEqualTo(1));

      final huge = srs.calculateNextReview(
        card(state: CardState.review, stability: 300, reviewCount: 40),
        Rating.easy,
      );
      expect(huge.intervalDays, lessThanOrEqualTo(365));
    });

    test('relearning + good → 回到 review，间隔 1 天', () {
      final r = srs.calculateNextReview(
          card(state: CardState.relearning), Rating.good);
      expect(r.newState, CardState.review);
      expect(r.intervalDays, 1);
    });

    test('difficulty clamp 1-10', () {
      final low = srs.calculateNextReview(card(difficulty: 1.0), Rating.easy);
      expect(low.difficulty, greaterThanOrEqualTo(1.0));

      final high = srs.calculateNextReview(
          card(difficulty: 10.0), Rating.again); // 10.0 + 1.5
      expect(high.difficulty, lessThanOrEqualTo(10.0));
    });
  });

  group('getIntervalPreview — Rating 按钮文案（f4 §7.4）', () {
    test('分钟级 / 天级 / 月级', () {
      final againPreview =
          srs.getIntervalPreview(card(), Rating.again);
      expect(againPreview, contains('m'));

      final goodPreview = srs.getIntervalPreview(card(), Rating.good);
      expect(goodPreview, '~1d');

      final far = srs.getIntervalPreview(
        card(state: CardState.review, stability: 100, reviewCount: 0),
        Rating.good,
      );
      expect(far, contains('mo'));
    });
  });
}
