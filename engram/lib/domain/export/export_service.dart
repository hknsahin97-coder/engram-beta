import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/media/media_store.dart';
import '../../data/local/prefs_settings_repository.dart';
import '../../data/repositories/isar_card_repository.dart';
import 'export_bundle.dart';

/// The result of an export -- so the interface can say what happened.
enum ExportOutcome {
  written,

  /// The user left without choosing a folder. Not an error.
  cancelled,

  failed,
}

class ExportResult {
  const ExportResult(this.outcome, {this.folder, this.cardCount = 0});

  final ExportOutcome outcome;
  final String? folder;
  final int cardCount;
}

final exportServiceProvider = Provider<ExportService>(ExportService.new);

/// Writes all data into a folder the user chooses.
///
/// ## Why `file_picker` and not `share_plus`
/// `file_picker` is already a dependency, so no new native plugin is needed.
/// Choosing a folder instead of opening a share sheet is also more honest:
/// the user sees where the backup goes.
///
/// ## Format
/// A single `engram-export.json` with a `media/` folder beside it. The media
/// paths inside the JSON are relative, so moving the file and the folder
/// together keeps them matched.
///
/// ## No automatic backup
/// It is triggered by hand. An app quietly writing files in the
/// background would blur the promise that everything stays on the device.
class ExportService {
  ExportService(this._ref);

  final Ref _ref;

  static const String jsonFileName = 'engram-export.json';
  static const String mediaFolderName = 'media';

  Future<ExportResult> run({DateTime? now}) async {
    String? folder;
    try {
      folder = await FilePicker.getDirectoryPath();
    } catch (e) {
      debugPrint('Could not choose a folder: $e');
      return const ExportResult(ExportOutcome.failed);
    }
    if (folder == null) return const ExportResult(ExportOutcome.cancelled);

    try {
      final repo = _ref.read(cardRepositoryProvider);
      final cards = await repo.list();
      final logs = await repo.allLogs();

      final bundle = ExportBundle.build(
        cards: cards,
        logs: logs,
        settings: _ref.read(settingsRepositoryProvider),
        exportedAt: now ?? DateTime.now(),
      );

      final jsonFile = File(p.join(folder, jsonFileName));
      // Written indented: the backup may one day have to be read by hand, and
      // a single-line JSON is useless at that moment.
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundle),
      );

      final media = _ref.read(mediaStoreProvider);
      var copied = 0;
      for (final card in cards) {
        for (final rel in [card.mediaPath, card.thumbnailPath]) {
          if (rel == null) continue;
          final source = media.resolve(rel);
          if (!source.existsSync()) continue;
          final target = File(p.join(folder, rel));
          await target.parent.create(recursive: true);
          await source.copy(target.path);
          copied++;
        }
      }
      debugPrint('Export: ${cards.length} cards, $copied media files');

      return ExportResult(
        ExportOutcome.written,
        folder: folder,
        cardCount: cards.length,
      );
    } catch (e, st) {
      debugPrint('Export failed: $e');
      debugPrintStack(stackTrace: st);
      return const ExportResult(ExportOutcome.failed);
    }
  }
}
