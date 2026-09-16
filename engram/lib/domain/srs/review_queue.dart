import '../../data/models/memory_card.dart';

/// Today's review queue.
///
/// **The raw pending-card count is deliberately not exposed.**
/// There is no `dueCount` field on this class; if there were, some widget would
/// display it one day. The only number that may be shown is [badgeCount].
class ReviewQueue {
  const ReviewQueue._({
    required this.cards,
    required this.badgeCount,
    required this.moreThanCap,
    required this.shouldShowCapHint,
  });

  /// The cards to review today, with the cap applied and interleaved.
  final List<MemoryCard> cards;

  /// The number shown on the islet badge -- `min(dueCount, dailyCap)`.
  ///
  /// The real accumulated total is never shown: a user who sees they
  /// owe 400 cards stops opening the app.
  final int badgeCount;

  /// Whether any cards were left out because of the cap.
  ///
  /// This is **not a number** but a yes/no: how many cards are waiting still
  /// appears nowhere. It is needed because the closing screen says
  /// "nothing else left"; with the cap in effect that is not true, and even a
  /// small lie is where trust starts to go.
  final bool moreThanCap;

  /// `true` when the user has hit the cap for the **first** time. A
  /// one-time message says the setting can be changed, then never appears again.
  final bool shouldShowCapHint;

  bool get isEmpty => cards.isEmpty;

  static const empty = ReviewQueue._(
    cards: [],
    badgeCount: 0,
    moreThanCap: false,
    shouldShowCapHint: false,
  );
}

abstract final class ReviewQueueBuilder {
  /// [due] must be **all** the cards that are due, sorted most overdue first
  /// (the repository's `getDue` provides that).
  ///
  /// Two steps, and the order matters:
  /// 1. The cap is applied -- the most overdue are selected.
  /// 2. The selection is interleaved by media type.
  ///
  /// In the other order, interleaving would pull less-overdue cards forward and
  /// destroy the meaning of the cap.
  static ReviewQueue build({
    required List<MemoryCard> due,
    required int dailyCap,
    required bool capHintAlreadyShown,
  }) {
    if (due.isEmpty) return ReviewQueue.empty;

    final hitCap = due.length > dailyCap;
    final selected = due.take(dailyCap).toList();

    return ReviewQueue._(
      cards: interleaveByType(selected),
      badgeCount: due.length < dailyCap ? due.length : dailyCap,
      moreThanCap: hitCap,
      shouldShowCapHint: hitCap && !capHintAlreadyShown,
    );
  }

  /// Stops cards of the same media type from arriving back to back
  /// (interleaving).
  ///
  /// Why: ten photo cards in a row is monotonous, and a mixed order is better
  /// for learning anyway. Each step takes from the **largest** bucket, but
  /// avoids the same type as the previous pick where possible -- so a single
  /// type does not pile up at the end.
  ///
  /// The overdue order inside a bucket is preserved.
  static List<MemoryCard> interleaveByType(List<MemoryCard> cards) {
    if (cards.length < 3) return List.of(cards);

    final buckets = <CardType, List<MemoryCard>>{};
    for (final card in cards) {
      buckets.putIfAbsent(card.type, () => []).add(card);
    }
    if (buckets.length < 2) return List.of(cards);

    final result = <MemoryCard>[];
    CardType? previous;

    while (result.length < cards.length) {
      final candidates = buckets.entries
          .where((e) => e.value.isNotEmpty)
          .toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      // Try to skip the previous type; if only one type is left, take it anyway.
      final pick = candidates.firstWhere(
        (e) => e.key != previous,
        orElse: () => candidates.first,
      );

      result.add(pick.value.removeAt(0));
      previous = pick.key;
    }

    return result;
  }
}
