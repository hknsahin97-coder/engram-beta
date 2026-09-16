import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// `ThemeData` construction. Colours come from [AppPalette]; the viewfinder
/// and paper surfaces are deliberately NOT included here (see tokens.dart).
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.accent,
      brightness: brightness,
    ).copyWith(
      // Seed-derived values are overridden with the brand's real ones --
      // the brand colour is too defining to leave to an algorithmic derivative.
      primary: AppPalette.accent,
      onPrimary: AppPalette.accentText,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      dividerColor: palette.border,
      extensions: [palette],

      fontFamily: 'Inter',
      textTheme: _textTheme(palette),

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // Sheets are rounded at the top and carry a shadow.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      // The capture field is borderless and focused; widgets add their own trim.
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        hintStyle: AppTextStyles.bodyM(palette.textSecondary),
        contentPadding: EdgeInsets.zero,
      ),

      splashFactory: InkRipple.splashFactory,
      highlightColor: palette.accentTint,
    );
  }

  static TextTheme _textTheme(AppPalette palette) {
    final primary = palette.textPrimary;
    final secondary = palette.textSecondary;
    return TextTheme(
      // Headings use "voice" -- the editorial tone comes from here.
      headlineMedium: AppTextStyles.heading(primary),
      titleLarge: AppTextStyles.question(primary),
      bodyLarge: AppTextStyles.bodyM(primary),
      bodyMedium: AppTextStyles.bodyM(primary),
      bodySmall: AppTextStyles.bodyS(secondary),
      labelLarge: AppTextStyles.button(primary),
      labelMedium: AppTextStyles.label(secondary),
      labelSmall: AppTextStyles.overline(secondary),
    );
  }
}
