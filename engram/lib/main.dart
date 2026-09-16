import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/media/media_store.dart';
import 'core/theme/theme_controller.dart';
import 'data/local/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app runs in portrait only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // The theme preference has to be known before the first frame -- otherwise a
  // dark-mode user sees a white flash on launch.
  final prefs = await SharedPreferences.getInstance();

  // The database and the media store are prepared at startup too: otherwise
  // every screen would have to carry a "loading" interim state.
  final isar = await IsarService.open();
  final mediaStore = await MediaStore.create();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        mediaStoreProvider.overrideWithValue(mediaStore),
      ],
      child: const EngramApp(),
    ),
  );
}
