// The unprefixed import is mandatory: isar_community_generator writes the enum
// types (State, Rating) unprefixed in the generated code. Imported `as fsrs`,
// the .g.dart does not compile -- and because *.g.dart is excluded from
// analysis, `flutter analyze` misses it; the error shows up under `flutter test`.
import 'package:fsrs/fsrs.dart';
import 'package:isar_community/isar.dart';

part 'memory_card.g.dart';

/// The content type of a card. The label on the review screen is derived from
/// it, and it is never shown on text cards.
///
/// **There is deliberately NO category or deck field.** As user input it would
/// add a step to every capture flow -- against the zero-friction decision.
enum CardType { text, photo, video, audio, pdfSnippet }

/// A single collection. **The media fields are part of the schema for every
/// card type**, so adding a capture mode never needs a schema migration.
///
/// ## Time zones
/// FSRS `reviewCard` throws when it sees a non-UTC `DateTime`, and Isar
/// converts to local time on read. So every time here is **written as UTC**
/// and `.toUtc()` is called before handing it to FSRS (see [fsrsCard]).
@collection
class MemoryCard {
  Id id = Isar.autoIncrement;

  // --- Content ---------------------------------------------------------

  @Enumerated(EnumType.name)
  late CardType type;

  /// The question in text mode. `null` on media cards.
  String? prompt;

  /// The text answer **or** the media note -- the same field.
  String? answer;

  String? mediaPath;
  String? thumbnailPath;
  int? mediaDurationMs;

  /// Playback start within the original media file, in milliseconds.
  ///
  /// Both bounds being nullable keeps older cards migration-free and allows
  /// trimming just one end: a `null` start is the beginning of the file and a
  /// `null` end is its end. Both `null` means no trim was applied; the file
  /// itself is never re-encoded.
  int? mediaStartMs;

  /// Playback end within the original media file, in milliseconds.
  int? mediaEndMs;

  /// E.g. "biology-notes.pdf · page 1". Only set on PDF excerpts.
  String? sourceLabel;

  @Index()
  late DateTime createdAt;

  // --- FSRS state -----------------------------------------------------
  //
  // Field names match Card exactly; no hand-written mapping.

  /// Stored with `EnumType.value`: `State` carries its own `value` field
  /// (learning=1, review=2, relearning=3). Bound to the value rather than the
  /// index, so reordering the enum cannot corrupt existing data.
  @Enumerated(EnumType.value, 'value')
  late State fsrsState;

  /// The learning/relearning step; `null` in the `review` state.
  ///
  /// **Mandatory:** without it, a card still in learning returns to the first
  /// step on every app launch.
  int? step;

  double? stability;
  double? difficulty;

  /// The next review time (UTC). The queue query uses this index.
  @Index()
  late DateTime dueAt;

  DateTime? lastReviewedAt;

  // --- Counts we keep ourselves ---------------------------------------
  //
  // Card does not carry these, but the learning level depends on both.
  // Rather than summing them from ReviewLog every time, they live here: the
  // Library list reads them for every card.

  /// Total number of reviews. `0` means the card is "New".
  late int reps;

  /// Number of reviews rated "Again". `>= 3` makes the card "Weak".
  late int lapses;

  MemoryCard();

  /// Creates a new card in FSRS's initial state.
  factory MemoryCard.create({
    required CardType type,
    String? prompt,
    String? answer,
    String? mediaPath,
    String? thumbnailPath,
    int? mediaDurationMs,
    int? mediaStartMs,
    int? mediaEndMs,
    String? sourceLabel,
    DateTime? now,
  }) {
    final createdAt = (now ?? DateTime.now()).toUtc();
    return MemoryCard()
      ..type = type
      ..prompt = prompt
      ..answer = answer
      ..mediaPath = mediaPath
      ..thumbnailPath = thumbnailPath
      ..mediaDurationMs = mediaDurationMs
      ..mediaStartMs = mediaStartMs
      ..mediaEndMs = mediaEndMs
      ..sourceLabel = sourceLabel
      ..createdAt = createdAt
      // New card: FSRS's default start -- in the learning state, on the first
      // step, reviewable immediately.
      ..fsrsState = State.learning
      ..step = 0
      ..stability = null
      ..difficulty = null
      ..dueAt = createdAt
      ..lastReviewedAt = null
      ..reps = 0
      ..lapses = 0;
  }

  /// Converts the Isar record into the object FSRS expects.
  ///
  /// The Isar `id` is passed as `cardId`: FSRS uses it only to tie the
  /// `ReviewLog` to the card, never in the calculation.
  @ignore
  Card get fsrsCard => Card(
        cardId: id,
        state: fsrsState,
        step: step,
        stability: stability,
        difficulty: difficulty,
        due: dueAt.toUtc(),
        lastReview: lastReviewedAt?.toUtc(),
      );

  /// Writes the state of the card returned by FSRS back into this record.
  ///
  /// When [wasLapse] is `true` (the user said "Again") [lapses] increases --
  /// the "Weak" classification looks at that.
  void applyFsrs(Card card, {required bool wasLapse}) {
    fsrsState = card.state;
    step = card.step;
    stability = card.stability;
    difficulty = card.difficulty;
    dueAt = card.due.toUtc();
    lastReviewedAt = card.lastReview?.toUtc();
    reps += 1;
    if (wasLapse) lapses += 1;
  }
}
