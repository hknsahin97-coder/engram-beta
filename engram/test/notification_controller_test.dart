import 'package:engram/core/notifications/notification_service.dart';
import 'package:engram/data/local/prefs_settings_repository.dart';
import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/repositories/card_repository.dart';
import 'package:engram/data/repositories/isar_card_repository.dart';
import 'package:engram/data/repositories/settings_repository.dart';
import 'package:engram/domain/notifications/notification_controller.dart';
import 'package:engram/domain/notifications/notification_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _texts = NotificationTexts(
  title: 'Engram',
  dailyWithCount: _withCount,
  dailyNoCount: 'A few cards are waiting for you',
  pileUp: 'Your cards have been stacking up',
  comeBack: 'Your cards are still here whenever you are',
);

String _withCount(int count) => '$count cards are waiting for you';

MemoryCard _dueCard(DateTime dueAt) =>
    MemoryCard.create(type: CardType.text, now: dueAt.toUtc())
      ..dueAt = dueAt.toUtc();

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  _FakeSettingsRepository({
    this.notificationsEnabled = true,
    this.notificationTime = const DayTime(20, 0),
    this.dailyCap = 25,
    this.lastOpenedAt,
    this.failWhenWritingLastOpenedAt = false,
  });

  @override
  bool notificationsEnabled;

  @override
  NotificationMode notificationMode = NotificationMode.dailyTime;

  @override
  DayTime notificationTime;

  @override
  bool showCountInNotification = true;

  @override
  int threshold = 50;

  @override
  int dailyCap;

  @override
  DateTime? lastOpenedAt;

  final bool failWhenWritingLastOpenedAt;
  int setLastOpenedAtCalls = 0;

  @override
  Future<void> setLastOpenedAt(DateTime value) async {
    setLastOpenedAtCalls++;
    if (failWhenWritingLastOpenedAt) {
      throw StateError('the settings store is unavailable');
    }
    lastOpenedAt = value;
  }
}

class _FakeCardRepository extends Fake implements CardRepository {
  _FakeCardRepository({
    this.cards = const [],
    this.lastReview,
  });

  final List<MemoryCard> cards;
  final DateTime? lastReview;
  int listCalls = 0;
  int lastReviewedAtCalls = 0;

  @override
  Future<List<MemoryCard>> list({
    CardSort sort = CardSort.newest,
    Set<CardType>? types,
  }) async {
    listCalls++;
    return cards;
  }

  @override
  Future<DateTime?> lastReviewedAt() async {
    lastReviewedAtCalls++;
    return lastReview;
  }
}

class _FakeNotificationService extends Fake implements NotificationService {
  _FakeNotificationService({this.failApplyWithLateInitializationError = false});

  final bool failApplyWithLateInitializationError;
  late final Object _platformChannel;
  int cancelAllCalls = 0;
  final List<List<PlannedNotification>> applyCalls = [];

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> apply(List<PlannedNotification> plans) async {
    applyCalls.add(List.unmodifiable(plans));
    if (failApplyWithLateInitializationError) {
      _platformChannel.hashCode;
    }
  }
}

ProviderContainer _container({
  required _FakeSettingsRepository settings,
  required _FakeCardRepository cards,
  required _FakeNotificationService service,
}) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      cardRepositoryProvider.overrideWithValue(cards),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('reschedule', () {
    test('with notifications off it only cancels the old schedules', () async {
      final settings = _FakeSettingsRepository(notificationsEnabled: false);
      final cards = _FakeCardRepository();
      final service = _FakeNotificationService();
      final container = _container(
        settings: settings,
        cards: cards,
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: DateTime(2026, 8, 5, 9));

      expect(service.cancelAllCalls, 1);
      expect(service.applyCalls, isEmpty);
      expect(cards.listCalls, 0,
          reason: 'a disabled feature should not touch the card store');
      expect(cards.lastReviewedAtCalls, 0);
    });

    test('when on, it applies the store snapshot to the platform service', () async {
      final now = DateTime(2026, 8, 5, 9);
      final cards = _FakeCardRepository(
        cards: [_dueCard(DateTime.utc(2026, 8, 5, 1))],
      );
      final service = _FakeNotificationService();
      final container = _container(
        settings: _FakeSettingsRepository(),
        cards: cards,
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: now);

      expect(cards.listCalls, 1);
      expect(cards.lastReviewedAtCalls, 1);
      expect(service.cancelAllCalls, 0,
          reason: 'the full cancel while enabled is apply\'s responsibility');
      expect(service.applyCalls, hasLength(1));
      expect(service.applyCalls.single, isNotEmpty);
    });

    test('it schedules the user hour locally from the UTC card date',
        () async {
      final now = DateTime(2026, 8, 5, 9);
      final service = _FakeNotificationService();
      final container = _container(
        settings: _FakeSettingsRepository(
          notificationTime: const DayTime(20, 37),
        ),
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.utc(2026, 8, 5, 1))],
        ),
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: now);

      final today = service.applyCalls.single.singleWhere(
        (plan) =>
            plan.kind == NotificationKind.dailyTime &&
            plan.when.year == now.year &&
            plan.when.month == now.month &&
            plan.when.day == now.day,
      );
      expect(today.when.isUtc, isFalse);
      expect((today.when.hour, today.when.minute), (20, 37));
    });

    test('it keeps today\'s reminder if the app was only opened today', () async {
      final now = DateTime(2026, 8, 5, 9);
      final service = _FakeNotificationService();
      final container = _container(
        settings: _FakeSettingsRepository(
          lastOpenedAt: DateTime(2026, 8, 5, 8),
        ),
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.utc(2026, 8, 5, 1))],
          lastReview: DateTime(2026, 8, 4, 20),
        ),
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: now);

      expect(
        service.applyCalls.single.where(
          (plan) =>
              plan.kind == NotificationKind.dailyTime &&
              plan.when.year == now.year &&
              plan.when.month == now.month &&
              plan.when.day == now.day,
        ),
        isNotEmpty,
        reason: 'opening the app to capture must not silence the review reminder',
      );
    });

    test('it does not schedule today\'s reminder if something was reviewed today', () async {
      final now = DateTime(2026, 8, 5, 9);
      final service = _FakeNotificationService();
      final container = _container(
        settings: _FakeSettingsRepository(),
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.utc(2026, 8, 5, 1))],
          lastReview: DateTime(2026, 8, 5, 8),
        ),
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: now);

      expect(
        service.applyCalls.single.where(
          (plan) =>
              plan.kind == NotificationKind.dailyTime &&
              plan.when.year == now.year &&
              plan.when.month == now.month &&
              plan.when.day == now.day,
        ),
        isEmpty,
        reason: 'a user who finished their work should not be nudged again the same day',
      );
    });

    test('it does not leak the raw accumulated card count into the text', () async {
      final now = DateTime(2026, 8, 5, 9);
      final service = _FakeNotificationService();
      final container = _container(
        settings: _FakeSettingsRepository(dailyCap: 25),
        cards: _FakeCardRepository(
          cards: List.generate(
            400,
            (_) => _dueCard(DateTime.utc(2026, 8, 5, 1)),
          ),
        ),
        service: service,
      );

      await container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: now);

      final bodies = service.applyCalls.single.map((plan) => plan.body);
      expect(bodies, contains('25 cards are waiting for you'));
      expect(bodies.any((body) => body.contains('400')), isFalse,
          reason: 'a notification must not show the user their accumulated review debt');
    });

    test('a LateInitializationError on the platform does not spill into the app flow',
        () async {
      final previousDebugPrint = debugPrint;
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);

      final service = _FakeNotificationService(
        failApplyWithLateInitializationError: true,
      );
      final container = _container(
        settings: _FakeSettingsRepository(),
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.utc(2026, 8, 5, 1))],
        ),
        service: service,
      );

      final result = container
          .read(notificationControllerProvider)
          .reschedule(_texts, now: DateTime(2026, 8, 5, 9));

      await expectLater(result, completes);
      expect(service.applyCalls, hasLength(1));
      expect(
        logs.join('\n'),
        contains('Notification scheduling failed: LateInitializationError'),
        reason: 'the error must not be swallowed; it stays diagnosable without breaking launch',
      );
    });
  });

  group('onAppOpened', () {
    test('it refreshes the plan after recording the last launch', () async {
      final before = DateTime.now();
      final settings = _FakeSettingsRepository();
      final service = _FakeNotificationService();
      final container = _container(
        settings: settings,
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.now().toUtc().subtract(const Duration(days: 1)))],
        ),
        service: service,
      );

      await container.read(notificationControllerProvider).onAppOpened(_texts);
      final after = DateTime.now();

      expect(settings.setLastOpenedAtCalls, 1);
      expect(settings.lastOpenedAt, isNotNull);
      expect(settings.lastOpenedAt!.isBefore(before), isFalse);
      expect(settings.lastOpenedAt!.isAfter(after), isFalse);
      expect(service.applyCalls, hasLength(1));
    });

    test('it refreshes the plan even if the last launch could not be written', () async {
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      addTearDown(() => debugPrint = previousDebugPrint);

      final settings = _FakeSettingsRepository(
        failWhenWritingLastOpenedAt: true,
      );
      final service = _FakeNotificationService();
      final container = _container(
        settings: settings,
        cards: _FakeCardRepository(
          cards: [_dueCard(DateTime.now().toUtc().subtract(const Duration(days: 1)))],
        ),
        service: service,
      );

      await expectLater(
        container.read(notificationControllerProvider).onAppOpened(_texts),
        completes,
      );
      expect(settings.setLastOpenedAtCalls, 1);
      expect(service.applyCalls, hasLength(1));
    });
  });
}
