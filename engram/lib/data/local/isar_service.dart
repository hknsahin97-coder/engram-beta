import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/memory_card.dart';
import '../models/review_log.dart';

/// Opens the Isar instance.
///
/// Opening happens inside `main()` and is injected through [isarProvider] --
/// the same as the theme preference. That way no screen has to show a
/// "loading database" interim state; the data is ready when the app opens.
abstract final class IsarService {
  static Future<Isar> open({String? directory, String name = 'engram'}) async {
    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
    return Isar.open(
      [MemoryCardSchema, ReviewLogSchema],
      directory: dir,
      name: name,
    );
  }
}

/// Overridden with the real instance inside `main()`.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden in main().');
});
