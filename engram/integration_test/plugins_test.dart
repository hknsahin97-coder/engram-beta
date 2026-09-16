// Native plugin checks that need no hardware, so they run unattended.
//
// Out of scope (needs a physical device and a person): camera preview, video
// recording, a real microphone, a real gallery.
//
// To run:  flutter test integration_test -d <device>
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:engram/data/local/isar_service.dart';
import 'package:engram/data/models/memory_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('native plugins', () {
    test('path_provider -- the directories can be obtained', () async {
      final docs = await getApplicationDocumentsDirectory();
      final tmp = await getTemporaryDirectory();

      expect(docs.existsSync(), isTrue, reason: 'the documents directory is missing');
      expect(tmp.existsSync(), isTrue, reason: 'the temporary directory is missing');
    });

    // Does Isar's native core load on this platform? A native library that
    // does not match the Dart side fails at run time, not at build time --
    // isar_community 3.3.1 is exactly such a release, which is why the
    // versions are pinned without a caret.
    test('Isar -- open, write, read, query', () async {
      final dir = await getApplicationDocumentsDirectory();
      final isar = await IsarService.open(
        directory: dir.path,
        name: 'integration_${DateTime.now().microsecondsSinceEpoch}',
      );

      addTearDown(() async {
        if (isar.isOpen) await isar.close(deleteFromDisk: true);
      });

      final card = MemoryCard.create(type: CardType.text, prompt: 'ci');
      await isar.writeTxn(() => isar.memoryCards.put(card));

      expect(await isar.memoryCards.count(), 1);

      final read = await isar.memoryCards.where().findFirst();
      expect(read, isNotNull);
      expect(read!.prompt, 'ci');
      // Isar may not store DateTime at microsecond precision.
      expect(
        read.createdAt.millisecondsSinceEpoch,
        closeTo(card.createdAt.millisecondsSinceEpoch, 1000),
      );
    });

    test('pdfx -- a PDF page renders to an image', () async {
      final tmp = await getTemporaryDirectory();
      final file = File(p.join(tmp.path, 'ci_smoke.pdf'));
      await file.writeAsBytes(_minimalPdf());
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });

      final doc = await PdfDocument.openFile(file.path);
      final page = await doc.getPage(1);
      final image = await page.render(width: page.width, height: page.height);

      expect(doc.pagesCount, 1);
      expect(page.width.round(), 420);
      expect(page.height.round(), 595);
      expect(image, isNotNull);
      expect(image!.bytes.length, greaterThan(0));

      await page.close();
      await doc.close();
    });

    // Instead of a microphone we use a WAV generated in code -- that way the
    // playback chain can be exercised without hardware.
    test('just_audio -- an audio file loads and plays', () async {
      final tmp = await getTemporaryDirectory();
      final file = File(p.join(tmp.path, 'ci_tone.wav'));
      await file.writeAsBytes(_silentWav(seconds: 1));
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });

      final player = AudioPlayer();
      addTearDown(player.dispose);

      final duration = await player.setFilePath(file.path);
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, closeTo(1000, 250));

      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(player.playing, isTrue);
      await player.stop();
    });

    // It does NOT ask for permission -- a permission dialog would hang an
    // unattended run.
    // The platform difference: Android records the schedule
    // even without permission, while iOS silently ignores zonedSchedule and
    // pendingNotificationRequests() comes back empty. So their expectations
    // diverge. What is checked is what is common and genuinely valuable on
    // both: plugin registration, timezone setup, and a clean round trip over
    // the platform channel. Delivery and permissions need a physical device.
    test('flutter_local_notifications -- a notification can be scheduled', () async {
      tzdata.initializeTimeZones();
      final plugin = FlutterLocalNotificationsPlugin();

      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      const id = 9101;
      addTearDown(() => plugin.cancel(id: id));

      await plugin.zonedSchedule(
        id: id,
        title: 'CI',
        body: 'scheduling test',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(days: 1)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('ci', 'CI'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      final pending = await plugin.pendingNotificationRequests();

      if (Platform.isAndroid) {
        expect(
          pending.map((e) => e.id),
          contains(id),
          reason: 'Android should record the schedule even without permission',
        );
      } else {
        // iOS: the list is expected to be empty because there is no permission.
        // The real check is that the call returns cleanly over the channel.
        expect(pending, isA<List<PendingNotificationRequest>>());
      }
    });
  });
}

/// The smallest valid PDF written by hand, one blank A5 page.
Uint8List _minimalPdf() {
  const pdf = '%PDF-1.4\n'
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 420 595]>>endobj\n'
      'trailer<</Root 1 0 R>>\n';
  return Uint8List.fromList(pdf.codeUnits);
}

/// An 8 kHz mono 16-bit WAV containing the given number of seconds of silence.
Uint8List _silentWav({required int seconds}) {
  const sampleRate = 8000;
  const bitsPerSample = 16;
  const channels = 1;
  const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  const blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = byteRate * seconds;

  final bytes = BytesBuilder();
  void str(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16); // PCM sub-chunk size
  u16(1); // format = PCM
  u16(channels);
  u32(sampleRate);
  u32(byteRate);
  u16(blockAlign);
  u16(bitsPerSample);
  str('data');
  u32(dataSize);
  bytes.add(Uint8List(dataSize)); // silence

  return bytes.toBytes();
}
