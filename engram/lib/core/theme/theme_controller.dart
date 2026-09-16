import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden with the real instance inside `main()` (see `main.dart`).
///
/// Why it loads at startup: if the theme preference were read asynchronously,
/// the app would paint its first frame with the default theme and a dark-mode
/// user would see a white flash on launch.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main().',
  );
});

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Theme preference: system / light / dark.
///
/// The APPEARANCE group in the settings sheet binds here.
class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _decode(prefs.getString(_key));
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, _encode(mode));
  }

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
