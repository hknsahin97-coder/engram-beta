import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../domain/srs/learning_level.dart';
import '../local/isar_service.dart';
import '../models/memory_card.dart';
import '../models/review_log.dart';
import 'card_repository.dart';

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => IsarCardRepository(ref.watch(isarProvider)),
);

class IsarCardRepository implements CardRepository {
  IsarCardRepository(this._isar);

  final Isar _isar;

  @override
  Future<int> add(MemoryCard card) =>
      _isar.writeTxn(() => _isar.memoryCards.put(card));

  @override
  Future<void> update(MemoryCard card) =>
      _isar.writeTxn(() => _isar.memoryCards.put(card));

  @override
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.memoryCards.delete(id);
      // No orphan logs: the statistics would keep counting deleted cards.
      await _isar.reviewLogs.filter().cardIdEqualTo(id).deleteAll();
    });
  }

  @override
  Future<MemoryCard?> getById(int id) => _isar.memoryCards.get(id);

  @override
  Future<List<MemoryCard>> getDue({required DateTime now, int? limit}) {
    final query = _isar.memoryCards
        .filter()
        .dueAtLessThan(now.toUtc(), include: true)
        // Most overdue first. Media interleaving and the daily cap are applied
        // in review_queue.dart, not here.
        .sortByDueAt();
    return limit == null ? query.findAll() : query.limit(limit).findAll();
  }

  @override
  Future<int> dueCount({required DateTime now}) => _isar.memoryCards
      .filter()
      .dueAtLessThan(now.toUtc(), include: true)
      .count();

  @override
  Stream<void> watchChanges() => _isar.memoryCards.watchLazy();

  @override
  Future<List<MemoryCard>> list({
    CardSort sort = CardSort.newest,
    Set<CardType>? types,
  }) async {
    final filtered = types == null || types.isEmpty
        ? await _isar.memoryCards.where().findAll()
        : await _isar.memoryCards
            .filter()
            .anyOf(types, (q, t) => q.typeEqualTo(t))
            .findAll();

    switch (sort) {
      case CardSort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CardSort.nextReview:
        filtered.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      case CardSort.weakest:
        // "Weakest" means most forgotten. The criterion is too compound to
        // express on the Isar side, so it is sorted in memory; for personal use
        // the card count stays in the thousands, so that is fine. Order: low
        // success first, ties broken by more lapses.
        filtered.sort((a, b) {
          final byAccuracy =
              (a.accuracy ?? 1.0).compareTo(b.accuracy ?? 1.0);
          if (byAccuracy != 0) return byAccuracy;
          return b.lapses.compareTo(a.lapses);
        });
    }
    return filtered;
  }

  @override
  Future<void> saveReview({
    required MemoryCard card,
    required ReviewLog log,
  }) {
    // One transaction: if the app closed in between, the card's FSRS state and
    // the statistics would stop agreeing.
    return _isar.writeTxn(() async {
      await _isar.memoryCards.put(card);
      await _isar.reviewLogs.put(log);
    });
  }

  @override
  Future<List<ReviewLog>> logsFor(int cardId) => _isar.reviewLogs
      .filter()
      .cardIdEqualTo(cardId)
      .sortByReviewedAtDesc()
      .findAll();

  @override
  Future<List<ReviewLog>> allLogs() =>
      _isar.reviewLogs.where().sortByReviewedAt().findAll();

  @override
  Future<DateTime?> lastReviewedAt() async {
    final last = await _isar.reviewLogs.where().sortByReviewedAtDesc().findFirst();
    return last?.reviewedAt;
  }

  @override
  Future<LibraryStats> stats() async {
    final total = await _isar.memoryCards.count();
    if (total == 0) return LibraryStats.empty;

    final cards = await _isar.memoryCards.where().findAll();
    final known = cards.where((c) => c.isKnown).length;

    // Overall success: the successful proportion across all reviews, not the
    // average per card -- a card reviewed 100 times should carry more weight
    // than one reviewed once.
    var reps = 0;
    var lapses = 0;
    for (final c in cards) {
      reps += c.reps;
      lapses += c.lapses;
    }

    return LibraryStats(
      totalCards: total,
      // No reviews means no rate -- showing "0% success" would be misleading.
      accuracy: reps == 0 ? null : (reps - lapses) / reps,
      knownCards: known,
    );
  }

  @override
  Future<void> deleteAll() => _isar.writeTxn(() async {
        await _isar.memoryCards.clear();
        await _isar.reviewLogs.clear();
      });
}
