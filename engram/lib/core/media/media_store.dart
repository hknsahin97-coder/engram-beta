import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The paths returned by a save. **Both are relative** -- open them with
/// [MediaStore.resolve].
class StoredMedia {
  const StoredMedia({required this.mediaPath, this.thumbnailPath});

  final String mediaPath;
  final String? thumbnailPath;
}

/// Copies captured media into the app's own directory and generates a
/// thumbnail.
///
/// ## Why relative paths are stored
/// On iOS the absolute path of the app container (`/var/mobile/.../Application/
/// <UUID>/`) **changes** across updates and reinstalls. Writing an absolute
/// path into the database would make all of a user's media appear lost after
/// an update. So only relative paths such as `media/foo.jpg` go into Isar, and
/// the absolute path is produced with [resolve] on every read.
///
/// ## Why files are copied
/// The camera and the gallery hand back temporary files, and the OS deletes
/// them whenever it likes. A card is permanent, so its media has to be too.
class MediaStore {
  MediaStore(this._documentsDirectory);

  final Directory _documentsDirectory;

  static const String _mediaDir = 'media';
  static const String _thumbDir = 'thumbnails';

  /// The long edge of a thumbnail. The Library shows a two-column grid, so
  /// anything larger just wastes space.
  static const int thumbnailMaxSide = 512;

  static Future<MediaStore> create() async =>
      MediaStore(await getApplicationDocumentsDirectory());

  /// Turns a relative path into a [File] that can be opened.
  File resolve(String relativePath) =>
      File(p.join(_documentsDirectory.path, relativePath));

  /// Moves [source] into the permanent directory and, for images, makes a thumbnail.
  ///
  /// Without [extension], the source's extension is used.
  Future<StoredMedia> save({
    required File source,
    required String idHint,
    bool makeThumbnail = false,
    String? extension,
  }) async {
    final ext = extension ?? p.extension(source.path).replaceFirst('.', '');
    final name = '${idHint}_${DateTime.now().microsecondsSinceEpoch}.$ext';

    final mediaRel = p.join(_mediaDir, name);
    final target = resolve(mediaRel);
    await target.parent.create(recursive: true);
    await source.copy(target.path);

    String? thumbRel;
    if (makeThumbnail) {
      thumbRel = await _writeThumbnail(target, name);
    }

    return StoredMedia(mediaPath: mediaRel, thumbnailPath: thumbRel);
  }

  /// Generates a thumbnail from an image. Returns `null` on failure -- a
  /// thumbnail is a convenience and must not block saving the card.
  Future<String?> _writeThumbnail(File image, String name) async {
    try {
      final decoded = img.decodeImage(await image.readAsBytes());
      if (decoded == null) return null;

      final resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: thumbnailMaxSide)
          : img.copyResize(decoded, height: thumbnailMaxSide);

      final thumbRel = p.join(_thumbDir, '${p.withoutExtension(name)}.jpg');
      final target = resolve(thumbRel);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(img.encodeJpg(resized, quality: 80));
      return thumbRel;
    } catch (_) {
      return null;
    }
  }

  /// Called while deleting a card. Passes silently if the file is missing.
  Future<void> deleteFiles(Iterable<String?> relativePaths) async {
    for (final rel in relativePaths) {
      if (rel == null) continue;
      final file = resolve(rel);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // A file we cannot delete must not block deleting the card; an
          // unreachable file is better than an inconsistent database.
        }
      }
    }
  }

  /// The "delete all data" flow.
  Future<void> deleteAll() async {
    for (final dir in [_mediaDir, _thumbDir]) {
      final d = Directory(p.join(_documentsDirectory.path, dir));
      if (d.existsSync()) await d.delete(recursive: true);
    }
  }
}

/// Overridden with the real instance inside `main()`.
final mediaStoreProvider = Provider<MediaStore>((ref) {
  throw UnimplementedError('mediaStoreProvider must be overridden in main().');
});
