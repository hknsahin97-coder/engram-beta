import 'dart:io';

import 'package:engram/core/media/media_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

Future<File> _sourceFile(
  Directory directory,
  String name,
  List<int> bytes,
) async {
  final file = File(p.join(directory.path, name));
  await file.parent.create(recursive: true);
  return file.writeAsBytes(bytes);
}

void _expectRelative(String path) {
  expect(p.isAbsolute(path), isFalse, reason: 'no absolute path should be stored: $path');
  expect(p.rootPrefix(path), isEmpty, reason: 'the root path must not leak: $path');
  expect(
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path),
    isFalse,
    reason: 'the drive letter must not leak: $path',
  );
  expect(
    path.startsWith('/') || path.startsWith(r'\'),
    isFalse,
    reason: 'the root separator must not leak: $path',
  );
}

void main() {
  late Directory sandbox;
  late Directory documents;
  late MediaStore store;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('engram_media_store_');
    documents = Directory(p.join(sandbox.path, 'app', 'documents'));
    store = MediaStore(documents);
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  group('the relative path invariant', () {
    test('only a relative media path is stored, from an absolute source', () async {
      // The source arrives absolute from the camera or the gallery; carrying
      // that into the database would break the card when the container moves.
      final source = await _sourceFile(
        sandbox,
        p.join('camera', 'shot.png'),
        [1, 2, 3, 4],
      );

      final saved = await store.save(source: source, idHint: 'card-7');

      _expectRelative(saved.mediaPath);
      expect(p.split(saved.mediaPath), hasLength(2));
      expect(p.split(saved.mediaPath).first, 'media');
      expect(
        p.basename(saved.mediaPath),
        matches(RegExp(r'^card-7_\d+\.png$')),
      );
    });

    test('both the media and the thumbnail paths are relative', () async {
      // The thumbnail is stored with the card too; leaving it absolute while the
      // main file is relative would reintroduce the same risk by the back door.
      final png = img.encodePng(img.Image(width: 8, height: 4));
      final source = await _sourceFile(sandbox, 'photo.png', png);

      final saved = await store.save(
        source: source,
        idHint: 'image',
        makeThumbnail: true,
      );

      _expectRelative(saved.mediaPath);
      _expectRelative(saved.thumbnailPath!);
      expect(p.split(saved.mediaPath).first, 'media');
      expect(p.split(saved.thumbnailPath!).first, 'thumbnails');
      expect(p.extension(saved.thumbnailPath!), '.jpg');
    });
  });

  group('resolution', () {
    test('relative and absolute paths round-trip', () async {
      final source = await _sourceFile(sandbox, 'voice.m4a', [9, 8, 7]);
      final saved = await store.save(source: source, idHint: 'voice');

      final absolute = store.resolve(saved.mediaPath);
      final relative = p.relative(absolute.path, from: documents.path);

      expect(p.equals(relative, saved.mediaPath), isTrue);
      expect(
        p.equals(store.resolve(relative).path, absolute.path),
        isTrue,
      );
      expect(await absolute.readAsBytes(), [9, 8, 7]);
    });

    test('Windows and POSIX separators preserve the same path components', () async {
      // What the database means is `media` plus the file name; the separator of
      // the OS running the test must not change those two or the round trip.
      final source = await _sourceFile(sandbox, 'document.pdf', [5, 4, 3]);
      final saved = await store.save(source: source, idHint: 'excerpt');
      final components = p.split(saved.mediaPath);
      final windowsPath = p.windows.joinAll(components);
      final posixPath = p.posix.joinAll(components);

      expect(p.windows.split(windowsPath), components);
      expect(p.posix.split(posixPath), components);
      expect(p.windows.isAbsolute(windowsPath), isFalse);
      expect(p.posix.isAbsolute(posixPath), isFalse);
      expect(
        p.split(p.relative(
          store.resolve(saved.mediaPath).path,
          from: documents.path,
        )),
        components,
      );
    });
  });

  group('file names and directories', () {
    test('consecutive saves with the same idHint do not collide', () async {
      // Two shots for the same card must not silently overwrite the earlier
      // file; if both survive, the timestamp really does prevent collisions.
      final firstSource = await _sourceFile(sandbox, 'first.bin', [1, 1, 1]);
      final secondSource = await _sourceFile(sandbox, 'second.bin', [2, 2, 2]);

      final first = await store.save(source: firstSource, idHint: 'same');
      final second = await store.save(source: secondSource, idHint: 'same');

      expect(second.mediaPath, isNot(first.mediaPath));
      expect(await store.resolve(first.mediaPath).readAsBytes(), [1, 1, 1]);
      expect(await store.resolve(second.mediaPath).readAsBytes(), [2, 2, 2]);
    });

    test('the extension comes from the source unless one is given', () async {
      // The camera can return a video as `.temp`; without honouring an explicit
      // extension, a valid video in the backup is recognised by no tool.
      final photo = await _sourceFile(sandbox, 'shot.JPEG', [1]);
      final video = await _sourceFile(sandbox, 'recording.temp', [2]);

      final savedPhoto = await store.save(source: photo, idHint: 'photo');
      final savedVideo = await store.save(
        source: video,
        idHint: 'video',
        extension: 'mp4',
      );

      expect(p.extension(savedPhoto.mediaPath), '.JPEG');
      expect(p.extension(savedVideo.mediaPath), '.mp4');
      expect(p.basenameWithoutExtension(savedVideo.mediaPath),
          matches(RegExp(r'^video_\d+$')));
    });

    test('it creates the missing media and thumbnails subdirectories', () async {
      final png = img.encodePng(img.Image(width: 3, height: 6));
      final source = await _sourceFile(sandbox, 'scan.png', png);

      expect(documents.existsSync(), isFalse);
      final saved = await store.save(
        source: source,
        idHint: 'scan',
        makeThumbnail: true,
      );

      expect(store.resolve(saved.mediaPath).existsSync(), isTrue);
      expect(store.resolve(saved.thumbnailPath!).existsSync(), isTrue);
      expect(
        p.equals(store.resolve(saved.mediaPath).parent.path,
            p.join(documents.path, 'media')),
        isTrue,
      );
      expect(
        p.equals(store.resolve(saved.thumbnailPath!).parent.path,
            p.join(documents.path, 'thumbnails')),
        isTrue,
      );
    });
  });
}
