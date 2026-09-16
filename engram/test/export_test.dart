import 'dart:convert';

import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/models/review_log.dart';
import 'package:engram/data/repositories/settings_repository.dart';
import 'package:engram/domain/export/export_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' hide ReviewLog;

/// An in-memory fake for settings -- export only reads.
class _FakeSettings implements SettingsRepository {
  @override
  int dailyCap = 25;
  @override
  bool notificationsEnabled = true;
  @override
  NotificationMode notificationMode = NotificationMode.threshold;
  @override
  DayTime notificationTime = const DayTime(21, 5);
  @override
  bool showCountInNotification = false;
  @override
  int threshold = 42;
  @override
  bool dailyCapHintShown = false;
  @override
  DateTime? lastOpenedAt;
  @override
  bool cameraGranted = false;

  @override
  Future<void> setDailyCap(int value) async => dailyCap = value;
  @override
  Future<void> setNotificationsEnabled(bool value) async =>
      notificationsEnabled = value;
  @override
  Future<void> setNotificationMode(NotificationMode value) async =>
      notificationMode = value;
  @override
  Future<void> setNotificationTime(DayTime value) async =>
      notificationTime = value;
  @override
  Future<void> setShowCountInNotification(bool value) async =>
      showCountInNotification = value;
  @override
  Future<void> setThreshold(int value) async => threshold = value;
  @override
  Future<void> markDailyCapHintShown() async => dailyCapHintShown = true;
  @override
  Future<void> setLastOpenedAt(DateTime value) async => lastOpenedAt = value;
  @override
  Future<void> setCameraGranted(bool value) async => cameraGranted = value;
  @override
  Future<void> resetAll() async {}
}

MemoryCard _fullCard() {
  return MemoryCard.create(
    type: CardType.pdfSnippet,
    prompt: 'the question',
    answer: 'the answer',
    mediaPath: 'media/a.jpg',
    thumbnailPath: 'thumbnails/a.jpg',
    mediaDurationMs: 4200,
    mediaStartMs: 800,
    mediaEndMs: 3600,
    sourceLabel: 'notes.pdf · page 2',
  )
    ..reps = 3
    ..lapses = 1
    ..stability = 4.5
    ..difficulty = 6.1
    ..lastReviewedAt = DateTime.utc(2026, 8, 1);
}

void main() {
  group('export bundle', () {
    test('EVERY field of the card goes into the file', () {
      // This test's real job is to fail when a field is added to the schema and
      // export is forgotten. If a backup silently loses data, the user finds
      // out only while restoring it -- the worst possible moment.
      final json = ExportBundle.cardToJson(_fullCard());
      expect(json.keys.toSet(), ExportBundle.cardFields);

      // No field should be empty on a fully populated card; if one is, the
      // mapping was written wrongly.
      for (final entry in json.entries) {
        expect(entry.value, isNotNull, reason: '${entry.key} came back empty');
      }
    });

    test('every field in the Isar schema is in the export list', () {
      // The hand-written lists are deliberate -- a list derived from the
      // model would stay green forever. But when both the mapping and the
      // expected list are maintained by hand, a field added to the schema can
      // be missing from both and the comparison above still matches.
      //
      // So the guard works both ways: the lists stay hand-written, and both
      // are verified against the definition Isar generates from the
      // **schema**.
      final schemaFields =
          MemoryCardSchema.properties.keys.toSet()..add('id');

      expect(
        ExportBundle.cardFields,
        containsAll(schemaFields),
        reason: 'a field added to the schema never entered the export',
      );
    });

    test('every field of the log goes into the file', () {
      final log = ReviewLog.create(
        cardId: 7,
        rating: Rating.good,
        reviewedAt: DateTime.utc(2026, 8, 2, 10),
        elapsedDays: 5,
        scheduledDays: 9,
      );
      final json = ExportBundle.logToJson(log);
      expect(json.keys.toSet(), ExportBundle.logFields);
      expect(json['rating'], 'good');
      expect(json['reviewedAt'], '2026-08-02T10:00:00.000Z');
    });

    test('every field of the settings goes into the file', () {
      final json = ExportBundle.settingsToJson(_FakeSettings());
      expect(json.keys.toSet(), ExportBundle.settingsFields);
      expect(json['notificationMode'], 'threshold');
      expect(json['notificationTime'], '21:05');
    });

    test('times are written as UTC and ISO-8601', () {
      // Every time in the database is UTC; if the backup drifted to local time,
      // card scheduling would shift on restore.
      final json = ExportBundle.cardToJson(_fullCard());
      expect(json['createdAt'], endsWith('Z'));
      expect(json['dueAt'], endsWith('Z'));
      expect(json['lastReviewedAt'], '2026-08-01T00:00:00.000Z');
    });

    test('the media path stays relative', () {
      // So it matches the `media/` folder in the backup: an absolute path would
      // point at nothing on another device.
      final json = ExportBundle.cardToJson(_fullCard());
      expect(json['mediaPath'], 'media/a.jpg');
    });

    test('the bundle can be encoded as JSON', () {
      final bundle = ExportBundle.build(
        cards: [_fullCard()],
        logs: const [],
        settings: _FakeSettings(),
        exportedAt: DateTime.utc(2026, 8, 11, 9),
      );

      final text = jsonEncode(bundle);
      final decoded = jsonDecode(text) as Map<String, Object?>;

      expect(decoded['formatVersion'], ExportBundle.formatVersion);
      expect(decoded['exportedAt'], '2026-08-11T09:00:00.000Z');
      expect((decoded['cards']! as List), hasLength(1));
      expect(decoded['reviewLogs'], isEmpty);
    });
  });
}
