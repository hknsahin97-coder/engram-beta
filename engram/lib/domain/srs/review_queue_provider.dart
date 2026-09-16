import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_settings_repository.dart';
import '../../data/repositories/isar_card_repository.dart';
import 'fsrs_scheduler.dart';
import 'rating.dart';
import 'review_queue.dart';

final fsrsSchedulerProvider = Provider<FsrsScheduler>((ref) => FsrsScheduler());

/// Fires on every change to the card table -- so badges and empty states
/// update by themselves.
final _cardChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(cardRepositoryProvider).watchChanges(),
);

/// Today's queue.
///
/// This is the **only** way to reach the cards due for review. `CardRepository`
/// must not be called directly to read a raw `dueCount` -- this single entry
/// point is what keeps the "the real total is never shown" rule alive.
final reviewQueueProvider = FutureProvider<ReviewQueue>((ref) async {
  // Listen for card changes so the queue refreshes after an add or a rating.
  ref.watch(_cardChangesProvider);

  final repo = ref.watch(cardRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  final now = DateTime.now().toUtc();

  final cap = settings.dailyCap;

  // We fetch one more than the cap: enough to know whether the cap was
  // exceeded, without pulling thousands of cards into memory.
  final due = await repo.getDue(now: now, limit: cap + 1);

  return ReviewQueueBuilder.build(
    due: due,
    dailyCap: cap,
    capHintAlreadyShown: settings.dailyCapHintShown,
  );
});

/// Applies a rating: runs FSRS, writes the card and the log in a single
/// transaction, and refreshes the queue.
final reviewActionsProvider = Provider<ReviewActions>(
  (ref) => ReviewActions(ref),
);

class ReviewActions {
  ReviewActions(this._ref);

  final Ref _ref;

  Future<void> rate({required int cardId, required Rating rating}) async {
    final repo = _ref.read(cardRepositoryProvider);
    final card = await repo.getById(cardId);
    if (card == null) return;

    final outcome = _ref.read(fsrsSchedulerProvider).review(
          card: card,
          rating: rating,
        );

    await repo.saveReview(card: outcome.card, log: outcome.log);
  }

  /// Called after the cap reminder has been shown (it is shown once only).
  Future<void> markCapHintShown() async {
    await _ref.read(settingsRepositoryProvider).markDailyCapHintShown();
    _ref.invalidate(reviewQueueProvider);
  }
}
