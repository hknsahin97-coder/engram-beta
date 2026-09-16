import 'package:fsrs/fsrs.dart' show Rating;

export 'package:fsrs/fsrs.dart' show Rating;

/// The **canonical order** of the four buttons on the review screen, left to right.
///
/// We define no enum of our own: `fsrs.Rating` is used
/// directly, so no hand-written mapping table forms between the buttons and the
/// scheduler. This list only fixes the **visual order**.
///
/// The order carries meaning: left to right is "did not remember at all" ->
/// "remembered". Ordered wrongly, the user presses the wrong button and the
/// scheduling silently breaks -- `rating_test.dart` guards it.
const List<Rating> ratingOrder = [
  Rating.again,
  Rating.hard,
  Rating.good,
  Rating.easy,
];

extension RatingSemantics on Rating {
  /// "Again" counts as a lapse: it increments the card's `lapses` counter and
  /// feeds the "Weak" classification.
  bool get isLapse => this == Rating.again;

  /// Everything other than "Again" is a success -- the success-rate calculation uses this.
  bool get isSuccess => !isLapse;
}
