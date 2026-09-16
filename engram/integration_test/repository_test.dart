// Verifying the card store against real Isar.
//
// Why integration_test: Isar is a native library and is absent from the
// `flutter test` environment, so these run on a device or emulator:
//     flutter test integration_test/repository_test.dart -d <device>
import 'dart:io';

import 'package:engram/data/local/isar_service.dart';
import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/models/review_log.dart';
import 'package:engram/data/repositories/card_repository.dart';
import 'package:engram/data/repositories/isar_card_repository.dart';
import 'package:engram/domain/srs/learning_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' hide ReviewLog;
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late CardRepository repo;

  setUp(() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await IsarService.open(
      directory: dir.path,
      // Each test gets its own database -- tests must not see each other's data.
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = IsarCardRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
  });

  MemoryCard textCard(String prompt, {DateTime? due}) {
    final card = MemoryCard.create(type: CardType.text, prompt: prompt);
    if (due != null) card.dueAt = due.toUtc();
    return card;
  }

  test('the MemoryCard and ReviewLog schemas open', () {
    // Do the MemoryCard and ReviewLog schemas open cleanly on a real, native
    // Isar build?
    expect(isar.isOpen, isTrue);
  });

  test('a card is added and read back', () async {
    final id = await repo.add(textCard('what is the capital'));
    final read = await repo.getById(id);

    expect(read, isNotNull);
    expect(read!.prompt, 'what is the capital');
    expect(read.type, CardType.text);
    expect(read.reps, 0);
    expect(read.level, LearningLevel.newCard);
  });

  test('enums are stored by value (renaming or reordering cannot break it)', () async {
    final card = textCard('x')..fsrsState = State.review;
    final id = await repo.add(card);

    expect((await repo.getById(id))!.fsrsState, State.review);
  });

  test('UTC times survive the round trip', () async {
    // Isar converts DateTime to local time on read; FSRS wants UTC.
    final due = DateTime.utc(2026, 8, 1, 9, 30);
    final id = await repo.add(textCard('x', due: due));

    final read = await repo.getById(id);
    expect(read!.dueAt.toUtc(), due);
    expect(read.fsrsCard.due.isUtc, isTrue);
  });

  group('queue query', () {
    test('the most overdue comes first', () async {
      final now = DateTime.utc(2026, 8, 1, 12);
      await repo.add(textCard('new', due: now.subtract(const Duration(hours: 1))));
      await repo.add(textCard('old', due: now.subtract(const Duration(days: 5))));
      await repo.add(textCard('future', due: now.add(const Duration(days: 1))));

      final due = await repo.getDue(now: now);

      expect(due.map((c) => c.prompt), ['old', 'new']);
    });

    test('a card due exactly now is included', () async {
      final now = DateTime.utc(2026, 8, 1, 12);
      await repo.add(textCard('exact', due: now));

      expect(await repo.dueCount(now: now), 1);
    });

    test('the limit is applied', () async {
      final now = DateTime.utc(2026, 8, 1, 12);
      for (var i = 0; i < 5; i++) {
        await repo.add(
          textCard('k$i', due: now.subtract(Duration(days: i + 1))),
        );
      }

      expect((await repo.getDue(now: now, limit: 2)).length, 2);
      // dueCount gives the raw number -- applying the cap is the queue's job.
      expect(await repo.dueCount(now: now), 5);
    });
  });

  test('a rating writes the card and the log in one transaction', () async {
    final card = textCard('x');
    final id = await repo.add(card);
    final stored = (await repo.getById(id))!;

    final scheduler = Scheduler();
    final result = scheduler.reviewCard(stored.fsrsCard, Rating.good);
    stored.applyFsrs(result.card, wasLapse: false);

    await repo.saveReview(
      card: stored,
      log: ReviewLog.create(
        cardId: id,
        rating: Rating.good,
        reviewedAt: DateTime.now().toUtc(),
        elapsedDays: 0,
        scheduledDays: 1,
      ),
    );

    final after = (await repo.getById(id))!;
    expect(after.reps, 1);
    expect(after.lapses, 0);
    expect(after.lastReviewedAt, isNotNull);
    expect((await repo.logsFor(id)).single.rating, Rating.good);
  });

  test('deleting a card deletes its logs', () async {
    final id = await repo.add(textCard('x'));
    await repo.saveReview(
      card: (await repo.getById(id))!..reps = 1,
      log: ReviewLog.create(
        cardId: id,
        rating: Rating.again,
        reviewedAt: DateTime.now().toUtc(),
        elapsedDays: 0,
        scheduledDays: 1,
      ),
    );

    await repo.delete(id);

    expect(await repo.getById(id), isNull);
    // Orphan logs would keep the statistics counting deleted cards.
    expect(await repo.logsFor(id), isEmpty);
  });

  group('library', () {
    test('newest-first ordering', () async {
      final a = textCard('a')..createdAt = DateTime.utc(2026, 1, 1);
      final b = textCard('b')..createdAt = DateTime.utc(2026, 6, 1);
      await repo.add(a);
      await repo.add(b);

      final list = await repo.list(sort: CardSort.newest);
      expect(list.first.prompt, 'b');
    });

    test('weakest-first ordering puts low success at the front', () async {
      await repo.add(textCard('good')
        ..reps = 10
        ..lapses = 1);
      await repo.add(textCard('bad')
        ..reps = 10
        ..lapses = 6);

      final list = await repo.list(sort: CardSort.weakest);
      expect(list.first.prompt, 'bad');
    });

    test('filter by type', () async {
      await repo.add(textCard('text'));
      await repo.add(MemoryCard.create(type: CardType.audio, answer: 'audio note'));

      final onlyAudio = await repo.list(types: {CardType.audio});
      expect(onlyAudio.single.type, CardType.audio);
    });
  });

  group('statistics', () {
    test('an empty summary when there are no cards', () async {
      expect((await repo.stats()).totalCards, 0);
      // Showing "0% success" would be misleading.
      expect((await repo.stats()).accuracy, isNull);
    });

    test('success is weighted by the number of reviews', () async {
      await repo.add(textCard('a')
        ..reps = 10
        ..lapses = 2);
      await repo.add(textCard('b')
        ..reps = 2
        ..lapses = 0);

      final stats = await repo.stats();
      expect(stats.totalCards, 2);
      // Not the average per card but across total reviews: 10/12
      expect(stats.accuracy, closeTo(10 / 12, 0.0001));
    });

    test('the known count uses the learning-level definition', () async {
      await repo.add(textCard('known')
        ..reps = 5
        ..stability = 40);
      await repo.add(textCard('learning')
        ..reps = 5
        ..stability = 3);

      expect((await repo.stats()).knownCards, 1);
    });
  });

  test('delete all data', () async {
    await repo.add(textCard('a'));
    await repo.deleteAll();

    expect((await repo.stats()).totalCards, 0);
  });

  test('media paths are stored relative', () async {
    // On iOS the app container path changes on update; writing an absolute path
    // would break all media.
    final id = await repo.add(
      MemoryCard.create(type: CardType.photo, mediaPath: 'media/a.jpg'),
    );

    final path = (await repo.getById(id))!.mediaPath!;
    expect(isRelativePath(path), isTrue, reason: 'no absolute path should be stored');
  });
}

bool isRelativePath(String path) =>
    !path.startsWith('/') && !RegExp(r'^[A-Za-z]:').hasMatch(path) &&
    !path.contains(Platform.pathSeparator + Platform.pathSeparator);
