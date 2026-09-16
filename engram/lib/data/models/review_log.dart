// The unprefixed import is mandatory -- see the note in memory_card.dart.
import 'package:fsrs/fsrs.dart' hide ReviewLog;
import 'package:isar_community/isar.dart';

part 'review_log.g.dart';

/// A record of every rating.
///
/// Why a separate collection:
/// - The success rate, review count and last-seen time in the Library card
///   detail are computed from it.
/// - Future FSRS parameter optimisation wants this history; the snapshot on
///   the card is not enough, the full review sequence is needed.
@collection
class ReviewLog {
  Id id = Isar.autoIncrement;

  /// [MemoryCard.id]. Deleting a card deletes its logs (the repository's job).
  @Index()
  late int cardId;

  /// Stored with `EnumType.value` -- `Rating` carries its own value
  /// (again=1, hard=2, good=3, easy=4). We define no enum of our own, so no
  /// hand-written mapping forms between the four buttons and FSRS.
  @Enumerated(EnumType.value, 'value')
  late Rating rating;

  /// UTC (see the time zone note on [MemoryCard]).
  @Index()
  late DateTime reviewedAt;

  /// The **real** number of days since the previous review.
  ///
  /// Note: the value handed to FSRS may differ. For cards more than 7 days
  /// overdue a clamped value is sent ("silent rescheduling") -- the
  /// truth is kept here so statistics stay honest and future optimisation runs
  /// on correct data.
  late int elapsedDays;

  /// The interval FSRS returned for this review, in days.
  late int scheduledDays;

  ReviewLog();

  factory ReviewLog.create({
    required int cardId,
    required Rating rating,
    required DateTime reviewedAt,
    required int elapsedDays,
    required int scheduledDays,
  }) {
    return ReviewLog()
      ..cardId = cardId
      ..rating = rating
      ..reviewedAt = reviewedAt.toUtc()
      ..elapsedDays = elapsedDays
      ..scheduledDays = scheduledDays;
  }

  /// Every rating other than "Again" counts as a success.
  ///
  /// The overall success rate in the Library summary and the "Weak"
  /// threshold (`success < 60%`) both use this definition.
  @ignore
  bool get isSuccess => rating != Rating.again;
}
