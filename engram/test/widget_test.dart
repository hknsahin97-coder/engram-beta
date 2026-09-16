import 'package:engram/app.dart';
import 'package:engram/core/theme/app_theme.dart';
import 'package:engram/core/theme/theme_controller.dart';
import 'package:engram/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  group('tokens', () {
    // These values are the design's colour tokens. The test guards against
    // them drifting silently.
    test('the palette matches the design tokens', () {
      expect(AppPalette.light.background, const Color(0xFFFAFAF9));
      expect(AppPalette.light.surface, const Color(0xFFFFFFFF));
      expect(AppPalette.light.textPrimary, const Color(0xFF1C1C1E));
      expect(AppPalette.light.textSecondary, const Color(0xFF8A8A8E));
      expect(AppPalette.light.border, const Color(0xFFECECEE));

      expect(AppPalette.dark.background, const Color(0xFF18181B));
      expect(AppPalette.dark.surface, const Color(0xFF232326));
      expect(AppPalette.dark.textPrimary, const Color(0xFFF4F3F1));
      expect(AppPalette.dark.textSecondary, const Color(0xFF9C9CA1));
      expect(AppPalette.dark.border, const Color(0xFF333338));

      expect(AppPalette.accent, const Color(0xFFB8684B));
    });

    test('the viewfinder and paper surfaces are theme-independent', () {
      // Mixing these three surfaces darkens the PDF or washes out the
      // viewfinder in dark mode. Fixed by design.
      expect(ViewfinderColors.surface.colors, [
        const Color(0xFF33363D),
        const Color(0xFF0D0D0F),
      ]);
      expect(PaperColors.surface, const Color(0xFFFFFFFF));
    });

    test('rating colours follow the FSRS order and stay readable', () {
      expect(RatingColors.again, const Color(0xFFE4483C));
      expect(RatingColors.hard, const Color(0xFFF59E0B));
      expect(RatingColors.good, const Color(0xFFFACC15));
      expect(RatingColors.easy, const Color(0xFF22C55E));

      // White text is unreadable on the yellow, so it takes dark text.
      expect(RatingColors.textOn(RatingColors.good), RatingColors.onGood);
      expect(RatingColors.textOn(RatingColors.again), RatingColors.onOther);
    });
  });

  group('theme', () {
    test('the light and dark themes carry the right palette', () {
      expect(
        AppTheme.light().extension<AppPalette>()!.background,
        AppPalette.light.background,
      );
      expect(
        AppTheme.dark().extension<AppPalette>()!.background,
        AppPalette.dark.background,
      );
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('the accent is not seed-derived; the brand value is preserved', () {
      expect(AppTheme.light().colorScheme.primary, AppPalette.accent);
      expect(AppTheme.dark().colorScheme.primary, AppPalette.accent);
    });
  });

  group('theme controller', () {
    test('the default follows the device setting', () async {
      final container = await _container();
      addTearDown(container.dispose);

      expect(container.read(themeControllerProvider), ThemeMode.system);
    });

    test('a saved preference is read at startup', () async {
      final container = await _container({'theme_mode': 'dark'});
      addTearDown(container.dispose);

      expect(container.read(themeControllerProvider), ThemeMode.dark);
    });

    test('a change is written persistently', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(themeControllerProvider.notifier).set(ThemeMode.dark);

      expect(container.read(themeControllerProvider), ThemeMode.dark);
      expect(
        container.read(sharedPreferencesProvider).getString('theme_mode'),
        'dark',
      );
    });
  });

  testWidgets('the app opens with the theme applied', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const EngramApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme!.extension<AppPalette>(), isNotNull);
    expect(app.darkTheme!.extension<AppPalette>(), isNotNull);
  });
}
