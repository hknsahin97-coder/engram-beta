import 'package:flutter/material.dart';

/// Design tokens.
///
/// **There are three independent surfaces and they must not be mixed:**
/// 1. Theme surface ([AppPalette]) -- changes with light/dark.
/// 2. Viewfinder surface ([ViewfinderColors]) -- *always* dark.
/// 3. Paper surface ([PaperColors]) -- *always* white.
///
/// The viewfinder and paper sit outside `ThemeData` on purpose: if the theme
/// variable leaked in, switching to dark mode would darken the PDF page or
/// wash out the viewfinder.

// ---------------------------------------------------------------------------
// Theme surface
// ---------------------------------------------------------------------------

/// Colours that change between the light and dark themes.
///
/// Carried as a `ThemeExtension`; read from a widget through `context.palette`
/// (see [PaletteContext]).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accentTint,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// The accent at low opacity -- selected chip, highlighted ground.
  /// Dark mode uses a higher opacity so it stays visible on a dark ground.
  final Color accentTint;

  /// Identical in both themes: the brand's terracotta.
  static const Color accent = Color(0xFFB8684B);
  static const Color accentText = Color(0xFFFFFFFF);

  static const AppPalette light = AppPalette(
    background: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8A8A8E),
    border: Color(0xFFECECEE),
    accentTint: Color(0x21B8684B), // rgba(184,104,75,0.13)
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF18181B),
    surface: Color(0xFF232326),
    textPrimary: Color(0xFFF4F3F1),
    textSecondary: Color(0xFF9C9CA1),
    border: Color(0xFF333338),
    accentTint: Color(0x38B8684B), // rgba(184,104,75,0.22)
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? accentTint,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      accentTint: accentTint ?? this.accentTint,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
    );
  }
}

/// `context.palette` shortcut -- so no widget has to spell out
/// `Theme.of(context).extension<..>()!`.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

// ---------------------------------------------------------------------------
// Viewfinder surface -- does NOT follow the theme
// ---------------------------------------------------------------------------

/// Camera, Import, Audio, photo/video crop and preview screens.
/// Always dark; it stays dark in the light theme too.
abstract final class ViewfinderColors {
  /// `linear-gradient(160deg, #33363D 0%, #0D0D0F 100%)`
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF33363D), Color(0xFF0D0D0F)],
  );

  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white

  /// The darkest end of the gradient. Used as the ground wherever a single
  /// colour is needed, such as behind a photo preview while it loads.
  static const Color deep = Color(0xFF0D0D0F);

  /// The confirmation sheet over the viewfinder.
  static const Color sheet = Color(0xFF17171A);

  /// Light fill over the viewfinder: icon buttons, the note field's ground.
  static const Color fill = Color(0x14FFFFFF);

  /// Record/shutter red. A separate colour from the accent -- the accent is
  /// the brand tone, this one signals "recording".
  static const Color record = Color(0xFFE4483C);
}

// ---------------------------------------------------------------------------
// Paper surface -- does NOT follow the theme
// ---------------------------------------------------------------------------

/// A PDF page is always shown on a white ground, including in dark mode.
abstract final class PaperColors {
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1C1C1E);
}

// ---------------------------------------------------------------------------
// Rating colours
// ---------------------------------------------------------------------------

/// The four buttons on the review screen. The order matches the FSRS `Rating`
/// enum exactly (Again/Hard/Good/Easy), so no hand-written mapping is needed.
///
/// Does not follow the theme: here colour carries meaning, not decoration.
abstract final class RatingColors {
  static const Color again = Color(0xFFE4483C);
  static const Color hard = Color(0xFFF59E0B);
  static const Color good = Color(0xFFFACC15);
  static const Color easy = Color(0xFF22C55E);

  /// The `good` yellow is unreadable with white text, so it takes dark text
  /// (`#3A2E00`).
  static const Color onGood = Color(0xFF3A2E00);
  static const Color onOther = Color(0xFFFFFFFF);

  /// A readable text colour on top of the given rating colour.
  static Color textOn(Color rating) =>
      rating == good ? onGood : onOther;
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// The spacing scale.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;
}

/// Corner radii.
abstract final class AppRadius {
  /// Thin elements such as waveform bars.
  static const double hairline = 2;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;

  /// The most common one: card, sheet row, rating button.
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;

  /// Top corners of bottom sheets.
  static const double sheet = 26;

  /// Chip, islet, round button.
  static const double pill = 999;
}

/// Micro-animation durations.
abstract final class AppDuration {
  /// Save feedback: the flight to the Library icon.
  ///
  /// Shorter durations read as a flicker rather than motion, and the
  /// animation's only job is to show where the saved thing went. It runs in an
  /// Overlay, so it never blocks the flow and nobody waits for it.
  static const Duration fly = Duration(milliseconds: 520);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);

  /// Perceptible transitions such as tap-to-reveal-answer.
  static const Duration reveal = Duration(milliseconds: 320);
}
