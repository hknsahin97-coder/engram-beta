import 'dart:async';

import 'package:engram/data/local/prefs_settings_repository.dart';
import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/models/review_log.dart';
import 'package:engram/data/repositories/card_repository.dart';
import 'package:engram/data/repositories/isar_card_repository.dart';
import 'package:engram/data/repositories/settings_repository.dart';
import 'package:engram/domain/srs/fsrs_scheduler.dart';
import 'package:engram/domain/srs/rating.dart';
import 'package:engram/domain/srs/review_queue_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _FakeCardRepository implements CardRepository {
  _FakeCardRepository({
    this.dueCards = const [],
    this.rawDueCount = 0,
    Map<int, MemoryCard>? cardsById,
  }) : cardsById = cardsById ?? {};

  final List<MemoryCard> dueCards;
  final int rawDueCount;
  final Map<int, MemoryCard> cardsById;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  final List<int?> requestedLimits = [];
  int dueCountCalls = 0;
  int getByIdCalls = 0;
  int saveReviewCalls = 0;
  MemoryCard? savedCard;
  ReviewLog? savedLog;

  Future<void> dispose() => _changes.close();

  @override
  Future<MemoryCard?> getById(int id) async {
    getByIdCalls++;
    return cardsById[id];
  }

  @override
  Future<List<MemoryCard>> getDue({required DateTime now, int? limit}) async {
    requestedLimits.add(limit);
    return dueCards.take(limit ?? dueCards.length).toList();
  }

  @override
  Future<int> dueCount({required DateTime now}) async {
    dueCountCalls++;
    return rawDueCount;
  }

  @override
  Stream<void> watchChanges() => _changes.stream;

  @override
  Future<void> saveReview({
    required MemoryCard card,
    required ReviewLog log,
  }) async {
    saveReviewCalls++;
    savedCard = card;
    savedLog = log;
  }

  @override
  Future<int> add(MemoryCard card) => throw UnimplementedError();

  @override
  Future<void> update(MemoryCard card) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<List<MemoryCard>> list({
    CardSort sort = CardSort.newest,
    Set<CardType>? types,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ReviewLog>> logsFor(int cardId) => throw UnimplementedError();

  @override
  Future<List<ReviewLog>> allLogs() => throw UnimplementedError();

  @override
  Future<DateTime?> lastReviewedAt() => throw UnimplementedError();

  @override
  Future<LibraryStats> stats() => throw UnimplementedError();

  @override
  Future<void> deleteAll() => throw UnimplementedError();
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings({required this.dailyCap});

  @override
  int dailyCap;
  @override
  bool dailyCapHintShown = false;
  int markDailyCapHintShownCalls = 0;

  @override
  Future<void> markDailyCapHintShown() async {
    markDailyCapHintShownCalls++;
    dailyCapHintShown = true;
  }

  @override
  bool notificationsEnabled = false;
  @override
  NotificationMode notificationMode = NotificationMode.dailyTime;
  @override
  DayTime notificationTime = const DayTime(20, 0);
  @override
  bool showCountInNotification = true;
  @override
  int threshold = 50;
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
  Future<void> setLastOpenedAt(DateTime value) async => lastOpenedAt = value;
  @override
  Future<void> setCameraGranted(bool value) async => cameraGranted = value;
  @override
  Future<void> resetAll() async {}
}

class _RecordingScheduler extends FsrsScheduler {
  _RecordingScheduler()
      : super(scheduler: fsrs.Scheduler(enableFuzzing: false));

  int reviewCalls = 0;

  @override
  ReviewOutcome review({
    required MemoryCard card,
    required Rating rating,
    DateTime? now,
  }) {
    reviewCalls++;
    return super.review(card: card, rating: rating, now: now);
  }
}

MemoryCard _card(int id) {
  final createdAt = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return MemoryCard.create(
    type: CardType.text,
    prompt: 'card-$id',
    now: createdAt,
  )..id = id;
}

ProviderContainer _container({
  required _FakeCardRepository repository,
  required _FakeSettings settings,
  _RecordingScheduler? scheduler,
}) {
  return ProviderContainer(
    overrides: [
      cardRepositoryProvider.overrideWith((ref) => repository),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      if (scheduler != null)
        fsrsSchedulerProvider.overrideWith((ref) => scheduler),
    ],
  );
}

void main() {
  group('reviewQueueProvider', () {
    test('the queue is bounded by the daily cap and leaves the rest out',
        () async {
      final repository = _FakeCardRepository(
        dueCards: [for (var id = 1; id <= 6; id++) _card(id)],
      );
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 3),
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      final queue = await container.read(reviewQueueProvider.future);

      expect(queue.cards.map((card) => card.id), [1, 2, 3]);
      expect(queue.badgeCount, 3);
    });

    test('the repository is queried for only the cap plus one card', () async {
      final repository = _FakeCardRepository(
        dueCards: [for (var id = 1; id <= 40; id++) _card(id)],
      );
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 25),
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container.read(reviewQueueProvider.future);

      // The extra one proves an overflow without pulling large piles into memory.
      expect(repository.requestedLimits, [26]);
    });

    test('only a yes/no signal leaves when the cap is exceeded', () async {
      final repository = _FakeCardRepository(
        dueCards: [for (var id = 1; id <= 100; id++) _card(id)],
        rawDueCount: 100,
      );
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 2),
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      final queue = await container.read(reviewQueueProvider.future);

      expect(queue.moreThanCap, isTrue);
      expect(queue.cards, hasLength(2));
      expect(queue.badgeCount, 2);
      // Not reading the raw total also stops it leaking into the UI by accident.
      expect(repository.dueCountCalls, 0);
    });

    test('with exactly the cap many cards the overflow signal stays off', () async {
      final repository = _FakeCardRepository(
        dueCards: [for (var id = 1; id <= 3; id++) _card(id)],
      );
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 3),
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      final queue = await container.read(reviewQueueProvider.future);

      expect(queue.moreThanCap, isFalse);
    });
  });

  group('ReviewActions', () {
    test('rate writes the card and the log from the FSRS result together', () async {
      final card = _card(7);
      final repository = _FakeCardRepository(cardsById: {card.id: card});
      final scheduler = _RecordingScheduler();
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 25),
        scheduler: scheduler,
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container
          .read(reviewActionsProvider)
          .rate(cardId: card.id, rating: Rating.good);

      expect(scheduler.reviewCalls, 1);
      expect(repository.saveReviewCalls, 1);
      expect(repository.savedCard, same(card));
      expect(repository.savedCard!.reps, 1);
      expect(repository.savedLog!.cardId, card.id);
      expect(repository.savedLog!.rating, Rating.good);
      expect(repository.savedLog!.reviewedAt.isUtc, isTrue);
    });

    test('a non-existent card id writes nothing, quietly', () async {
      final repository = _FakeCardRepository();
      final scheduler = _RecordingScheduler();
      final container = _container(
        repository: repository,
        settings: _FakeSettings(dailyCap: 25),
        scheduler: scheduler,
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container
          .read(reviewActionsProvider)
          .rate(cardId: 404, rating: Rating.again);

      expect(repository.getByIdCalls, 1);
      expect(scheduler.reviewCalls, 0);
      expect(repository.saveReviewCalls, 0);
    });

    test('markCapHintShown shows the reminder permanently once',
        () async {
      final repository = _FakeCardRepository(
        dueCards: [for (var id = 1; id <= 3; id++) _card(id)],
      );
      final settings = _FakeSettings(dailyCap: 2);
      final container = _container(
        repository: repository,
        settings: settings,
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      final firstQueue = await container.read(reviewQueueProvider.future);
      expect(firstQueue.shouldShowCapHint, isTrue);

      await container.read(reviewActionsProvider).markCapHintShown();
      final refreshedQueue = await container.read(reviewQueueProvider.future);

      expect(settings.markDailyCapHintShownCalls, 1);
      expect(refreshedQueue.moreThanCap, isTrue);
      expect(refreshedQueue.shouldShowCapHint, isFalse);
    });
  });
}
