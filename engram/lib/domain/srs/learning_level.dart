import '../../data/models/memory_card.dart';

/// A card's learning level.
///
/// The Library filter, the "Known cards" box in the Library summary and
/// the "weakest" sort all use this definition.
enum LearningLevel { newCard, weak, learning, known }

/// The "Known" threshold: a card whose FSRS stability exceeds this value counts
/// as well known.
const Duration knownStabilityThreshold = Duration(days: 21);

/// How many "Again" ratings are needed to count as weak.
const int weakLapseThreshold = 3;

/// The success-rate threshold for counting as weak.
const double weakAccuracyThreshold = 0.60;

extension MemoryCardLevel on MemoryCard {
  /// The card's success rate, `0..1`. `null` if it has never been reviewed.
  ///
  /// Needs no log query: `lapses` is the "Again" count, so the successful
  /// reviews are `reps - lapses`.
  double? get accuracy {
    if (reps == 0) return null;
    return (reps - lapses) / reps;
  }

  /// **Order matters, first match wins.**
  ///
  /// In particular `weak` comes before `learning`: a card that is forgotten
  /// often but whose stability has risen should still count as weak.
  LearningLevel get level {
    if (reps == 0) return LearningLevel.newCard;

    final acc = accuracy;
    if (lapses >= weakLapseThreshold ||
        (acc != null && acc < weakAccuracyThreshold)) {
      return LearningLevel.weak;
    }

    final days = stability ?? 0;
    if (days < knownStabilityThreshold.inDays) return LearningLevel.learning;

    return LearningLevel.known;
  }

  bool get isKnown => level == LearningLevel.known;
}
