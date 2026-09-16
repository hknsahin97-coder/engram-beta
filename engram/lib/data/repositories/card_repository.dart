import '../models/memory_card.dart';
import '../models/review_log.dart';

/// Library sort options.
enum CardSort {
  /// Newest first.
  newest,

  /// Weakest first -- close to the "Weak" definition: most forgotten first.
  weakest,

  /// By next review time.
  nextReview,
}

/// The three boxes in the Library summary.
class LibraryStats {
  const LibraryStats({
    required this.totalCards,
    required this.accuracy,
    required this.knownCards,
  });

  final int totalCards;

  /// In the 0..1 range. `null` when there are no reviews -- showing "0%
  /// success" would be misleading and blaming; "no data yet" is the truth.
  final double? accuracy;

  final int knownCards;

  static const empty =
      LibraryStats(totalCards: 0, accuracy: null, knownCards: 0);
}

/// The **interface** of the card store. The UI and domain layers never see
/// Isar directly -- so the upper layers survive a database change,
/// and a fake implementation can be supplied in tests.
abstract interface class CardRepository {
  Future<int> add(MemoryCard card);

  Future<void> update(MemoryCard card);

  /// Deletes the card together with all of its [ReviewLog] records.
  Future<void> delete(int id);

  Future<MemoryCard?> getById(int id);

  /// Cards reviewable at [now], most overdue first.
  ///
  /// The [limit] here is a raw page bound -- it is **not** the daily cap.
  /// The cap and media interleaving are `review_queue.dart`'s job.
  Future<List<MemoryCard>> getDue({required DateTime now, int? limit});

  /// The number of reviewable cards.
  ///
  /// **Careful:** this raw number is never shown to the user.
  /// The islet badge shows `min(dueCount, dailyCap)`.
  Future<int> dueCount({required DateTime now});

  /// So that badges and empty states update live.
  Stream<void> watchChanges();

  Future<List<MemoryCard>> list({
    CardSort sort = CardSort.newest,
    Set<CardType>? types,
  });

  /// Writes a rating **in a single transaction**: the card's updated FSRS state
  /// and its log. Written separately, the statistics would be left inconsistent
  /// with the card if the app closed in between.
  Future<void> saveReview({
    required MemoryCard card,
    required ReviewLog log,
  });

  Future<List<ReviewLog>> logsFor(int cardId);

  /// The whole review history -- used only by export.
  ///
  /// Calling `logsFor` per card would mean a thousand queries for a thousand
  /// cards, and the user is waiting while the backup runs.
  Future<List<ReviewLog>> allLogs();

  /// When any card was last rated. `null` if nothing has been reviewed yet.
  ///
  /// Notification scheduling uses this: "was anything reviewed today?" is a
  /// different question from "was the app opened today?" -- in this app,
  /// opening usually means capturing.
  Future<DateTime?> lastReviewedAt();

  Future<LibraryStats> stats();

  /// The "delete all data" flow in Settings.
  Future<void> deleteAll();
}
