import 'package:flutter/material.dart';

/// The app has two voices:
///
/// - [AppText.voice] -- Fraunces. The user's **own words** and editorial
///   headings. Six places only: main capture text, review card question,
///   closing title, Library title, card detail answer, empty state title.
/// - [AppText.body] -- Inter. Everything else: buttons, labels, settings,
///   statistics.
///
/// **Why is weight applied through `fontVariations`?**
/// The files under `assets/fonts/` are *variable fonts* (see `pubspec.yaml`).
/// With no static cut, `fontWeight` alone does not change the weight -- the
/// `wght` axis has to be driven explicitly.
/// `fontWeight` is still passed: Flutter uses it for line height and for any
/// fallback font selection.
abstract final class AppText {
  static const String _voiceFamily = 'Fraunces';
  static const String _bodyFamily = 'Inter';

  /// Fraunces. The design uses only weights 500 and 600.
  ///
  /// TODO: Fraunces' `opsz` (optical size) axis sits at its default. Higher
  /// `opsz` may read better at large sizes.
  static TextStyle voice({
    required double size,
    int weight = 600,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    assert(
      weight == 500 || weight == 600,
      'The design uses only 500 and 600 for Fraunces; '
      'a new weight needs a design decision first.',
    );
    return TextStyle(
      fontFamily: _voiceFamily,
      fontSize: size,
      fontWeight: _toFontWeight(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Inter. 400/500/600/700 are used.
  static TextStyle body({
    required double size,
    int weight = 400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: _bodyFamily,
      fontSize: size,
      fontWeight: _toFontWeight(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static FontWeight _toFontWeight(int weight) {
    return switch (weight) {
      <= 400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      _ => FontWeight.w700,
    };
  }
}

/// Recurring text sizes. Before adding a new size, check whether one of these
/// already works -- restraint applies to typography as much as to the rest of
/// the design.
abstract final class AppTextStyles {
  /// Main capture area -- the note the user types.
  static TextStyle capture(Color color) =>
      AppText.voice(size: 22, weight: 500, color: color, height: 1.35);

  /// The question on a review card.
  static TextStyle question(Color color) =>
      AppText.voice(size: 21, color: color, height: 1.3);

  /// Card detail / closing / empty state heading.
  static TextStyle heading(Color color) =>
      AppText.voice(size: 19, color: color, height: 1.3);

  /// Body text.
  static TextStyle bodyM(Color color) =>
      AppText.body(size: 15, color: color, height: 1.4);

  /// Secondary explanation.
  static TextStyle bodyS(Color color) =>
      AppText.body(size: 13, color: color, height: 1.4);

  /// Button label.
  static TextStyle button(Color color) =>
      AppText.body(size: 16, weight: 600, color: color);

  /// Chip, tag.
  static TextStyle label(Color color) =>
      AppText.body(size: 13, weight: 500, color: color);

  /// Uppercase editorial labels such as "QUESTION".
  static TextStyle overline(Color color) => AppText.body(
        size: 11,
        weight: 600,
        color: color,
        letterSpacing: 0.8,
      );
}
