import 'package:fsrs/fsrs.dart' as fsrs;

import '../../data/models/memory_card.dart';
import '../../data/models/review_log.dart';
import 'rating.dart';

/// The result of a rating: the updated card and the log to write.
class ReviewOutcome {
  const ReviewOutcome({required this.card, required this.log});

  final MemoryCard card;
  final ReviewLog log;
}

/// The FSRS wrapper.
///
/// Its job is not only to call the library -- **"silent rescheduling"** is
/// applied here. That rule is one of the things that give the app its
/// character, so it lives in one place and in the open.
class FsrsScheduler {
  FsrsScheduler({fsrs.Scheduler? scheduler})
      : _scheduler = scheduler ?? fsrs.Scheduler();

  final fsrs.Scheduler _scheduler;

  /// The overdue clamping ceiling.
  ///
  /// A user returning after a long break would, in FSRS's eyes, find every card
  /// "unseen for 60 days"; the library reads that as low retrievability and
  /// drops their stability hard. The result: someone who takes a week off comes
  /// back to a collapsed deck. This ceiling limits the elapsed time used in the
  /// calculation to 7 days -- **the user is not punished.**
  ///
  /// Note: this only affects the value handed to FSRS. [ReviewLog.elapsedDays]
  /// stores the real interval, so statistics stay honest.
  static const Duration maxElapsed = Duration(days: 7);

  /// Processes a rating and produces the card's new state.
  ///
  /// [card] is **mutated in place** (`applyFsrs`) and the returned
  /// [ReviewOutcome] carries the same instance -- the caller writes both in one transaction.
  ReviewOutcome review({
    required MemoryCard card,
    required Rating rating,
    DateTime? now,
  }) {
    final reviewedAt = (now ?? DateTime.now()).toUtc();
    final lastReview = card.lastReviewedAt?.toUtc();

    final realElapsedDays =
        lastReview == null ? 0 : reviewedAt.difference(lastReview).inDays;

    // FSRS computes elapsed time from the card's `lastReview` field; we cannot
    // tell it "this many days have passed" from outside. So the clamp works by
    // moving lastReview forward. The shifted value is used ONLY in the
    // calculation and never written to the database -- reviewCard already sets
    // lastReview to reviewedAt on the way back.
    final input = card.fsrsCard;
    if (lastReview != null && reviewedAt.difference(lastReview) > maxElapsed) {
      input.lastReview = reviewedAt.subtract(maxElapsed);
    }

    final result = _scheduler.reviewCard(
      input,
      rating,
      reviewDateTime: reviewedAt,
    );

    card.applyFsrs(result.card, wasLapse: rating.isLapse);

    return ReviewOutcome(
      card: card,
      log: ReviewLog.create(
        cardId: card.id,
        rating: rating,
        reviewedAt: reviewedAt,
        // The real interval -- not the clamped one.
        elapsedDays: realElapsedDays,
        scheduledDays: card.dueAt.toUtc().difference(reviewedAt).inDays,
      ),
    );
  }

  /// Says whether a card is overdue; for testing whether the clamp engaged, and
  /// for diagnosis later.
  bool wasClamped({required MemoryCard card, required DateTime now}) {
    final last = card.lastReviewedAt?.toUtc();
    if (last == null) return false;
    return now.toUtc().difference(last) > maxElapsed;
  }

  /// Whether a card is reviewable right now.
  static bool isDue(MemoryCard card, DateTime now) =>
      !card.dueAt.toUtc().isAfter(now.toUtc());
}
