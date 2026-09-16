import 'package:engram/data/models/memory_card.dart';
import 'package:engram/domain/srs/fsrs_scheduler.dart';
import 'package:engram/domain/srs/rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Fuzzing is off: the default `Scheduler` adds randomness to intervals (good
/// in production -- reviews do not pile onto the same day) but it makes test
/// results move around.
FsrsScheduler _scheduler() =>
    FsrsScheduler(scheduler: fsrs.Scheduler(enableFuzzing: false));

/// A card in the `review` state that has not been seen for a while.
MemoryCard _reviewedCard({required DateTime now, required int daysAgo}) {
  final last = now.subtract(Duration(days: daysAgo));
  return MemoryCard.create(type: CardType.text, prompt: 'x', now: last)
    ..id = 1
    ..fsrsState = fsrs.State.review
    ..step = null
    ..stability = 10
    ..difficulty = 5
    ..reps = 3
    ..lapses = 0
    ..lastReviewedAt = last
    ..dueAt = last.add(const Duration(days: 10));
}

void main() {
  final now = DateTime.utc(2026, 8, 1, 12);

  group('rating order', () {
    test('the four buttons match the FSRS values exactly', () {
      // Break the order and the user presses the wrong button; the scheduling
      // then works silently wrongly -- no error, just wrong.
      expect(ratingOrder, [
        fsrs.Rating.again,
        fsrs.Rating.hard,
        fsrs.Rating.good,
        fsrs.Rating.easy,
      ]);
      expect(ratingOrder.map((r) => r.value), [1, 2, 3, 4]);
    });

    test('only "Again" counts as a lapse', () {
      expect(fsrs.Rating.again.isLapse, isTrue);
      for (final r in [fsrs.Rating.hard, fsrs.Rating.good, fsrs.Rating.easy]) {
        expect(r.isLapse, isFalse, reason: '$r should not count as a lapse');
      }
    });
  });

  group('overdue clamping', () {
    test('more than 7 days overdue is clamped to 7 days', () {
      // Two identical cards, 60 and 7 days overdue, must give the same result:
      // someone back from holiday is punished no more than someone away a week.
      final long = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 60),
        rating: fsrs.Rating.good,
        now: now,
      );
      final atLimit = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 7),
        rating: fsrs.Rating.good,
        now: now,
      );

      expect(long.card.stability, closeTo(atLimit.card.stability!, 0.0001));
      expect(long.card.dueAt, atLimit.card.dueAt);
    });

    test('an overdue of less than 7 days is used as it is', () {
      final short = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 3),
        rating: fsrs.Rating.good,
        now: now,
      );
      final atLimit = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 7),
        rating: fsrs.Rating.good,
        now: now,
      );

      // Because the clamp does not engage, the results must differ; identical
      // results would mean the clamp is applied to every card by mistake.
      expect(short.card.stability, isNot(closeTo(atLimit.card.stability!, 0.01)));
    });

    // The easiest part of the clamp to miss: it must affect only the value
    // handed to FSRS, NOT the history that gets stored.
    test('the log stores the real elapsed time, not the clamped one', () {
      final outcome = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 60),
        rating: fsrs.Rating.good,
        now: now,
      );

      expect(outcome.log.elapsedDays, 60);
    });

    test('clamp detection', () {
      final s = _scheduler();
      expect(
        s.wasClamped(card: _reviewedCard(now: now, daysAgo: 60), now: now),
        isTrue,
      );
      expect(
        s.wasClamped(card: _reviewedCard(now: now, daysAgo: 2), now: now),
        isFalse,
      );
    });

    test('no clamping on a card that was never reviewed', () {
      final fresh = MemoryCard.create(type: CardType.text, now: now)..id = 1;
      expect(_scheduler().wasClamped(card: fresh, now: now), isFalse);

      final outcome =
          _scheduler().review(card: fresh, rating: fsrs.Rating.good, now: now);
      expect(outcome.log.elapsedDays, 0);
    });
  });

  group('rating outcome', () {
    test('"Again" increments the lapses counter', () {
      final outcome = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 3),
        rating: fsrs.Rating.again,
        now: now,
      );

      expect(outcome.card.lapses, 1);
      expect(outcome.card.reps, 4);
    });

    test('a successful rating does not increment lapses', () {
      final outcome = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 3),
        rating: fsrs.Rating.easy,
        now: now,
      );

      expect(outcome.card.lapses, 0);
      expect(outcome.card.reps, 4);
    });

    test('after a review the card is scheduled forward and stays UTC', () {
      final outcome = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 3),
        rating: fsrs.Rating.good,
        now: now,
      );

      expect(outcome.card.dueAt.isAfter(now), isTrue);
      expect(outcome.card.dueAt.isUtc, isTrue);
      expect(outcome.card.lastReviewedAt!.isUtc, isTrue);
      expect(outcome.log.reviewedAt.isUtc, isTrue);
    });

    test('the clamped lastReview does not leak into the database', () {
      // We move lastReview forward for the calculation; the value stored has to
      // be the real review time.
      final outcome = _scheduler().review(
        card: _reviewedCard(now: now, daysAgo: 60),
        rating: fsrs.Rating.good,
        now: now,
      );

      expect(outcome.card.lastReviewedAt, now);
    });
  });

  test('isDue includes a card that is due exactly now', () {
    final card = MemoryCard.create(type: CardType.text, now: now)..dueAt = now;
    expect(FsrsScheduler.isDue(card, now), isTrue);
    expect(
      FsrsScheduler.isDue(card, now.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });
}
