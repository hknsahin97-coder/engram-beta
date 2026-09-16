import 'package:engram/data/models/memory_card.dart';
import 'package:engram/domain/srs/learning_level.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryCard _card({
  int reps = 0,
  int lapses = 0,
  double? stability,
}) {
  return MemoryCard.create(type: CardType.text, prompt: 'x')
    ..reps = reps
    ..lapses = lapses
    ..stability = stability;
}

void main() {
  group('success rate', () {
    test('null when never reviewed', () {
      // Showing "0% success" would be misleading and blaming.
      expect(_card().accuracy, isNull);
    });

    test('no log query needed, because lapses is the "Again" count', () {
      expect(_card(reps: 10, lapses: 2).accuracy, 0.8);
      expect(_card(reps: 4, lapses: 4).accuracy, 0.0);
    });
  });

  group('learning level', () {
    test('reps == 0 → New', () {
      expect(_card().level, LearningLevel.newCard);
    });

    test('lapses >= 3 → Weak', () {
      expect(_card(reps: 20, lapses: 3, stability: 40).level,
          LearningLevel.weak);
    });

    test('success < 60% -> Weak (even with lapses below the threshold)', () {
      final card = _card(reps: 4, lapses: 2, stability: 40);
      expect(card.lapses, lessThan(weakLapseThreshold));
      expect(card.accuracy, lessThan(weakAccuracyThreshold));
      expect(card.level, LearningLevel.weak);
    });

    test('stability < 21 days -> Learning', () {
      expect(_card(reps: 5, lapses: 0, stability: 20.9).level,
          LearningLevel.learning);
    });

    test('stability >= 21 days -> Known', () {
      expect(_card(reps: 5, lapses: 0, stability: 21).level,
          LearningLevel.known);
      expect(_card(reps: 5, lapses: 0, stability: 21).isKnown, isTrue);
    });

    // The "order matters, first match wins" rule. Without this test the order
    // of the conditions could be changed silently, and a card forgotten often
    // would look "Known" thanks to its high stability.
    test('Weak comes before Known', () {
      final forgetful = _card(reps: 30, lapses: 10, stability: 200);
      expect(forgetful.level, LearningLevel.weak,
          reason: 'an often-forgotten card should count as weak despite high stability');
    });

    test('Learning when stability is null (no FSRS data yet)', () {
      expect(_card(reps: 1, lapses: 0).level, LearningLevel.learning);
    });
  });

  group('MemoryCard.create', () {
    test('a new card is immediately reviewable and its counters are zero', () {
      final now = DateTime.utc(2026, 8, 1, 12);
      final card = MemoryCard.create(
        type: CardType.text,
        prompt: 'a question',
        now: now,
      );

      expect(card.reps, 0);
      expect(card.lapses, 0);
      expect(card.step, 0);
      expect(card.dueAt, now);
      expect(card.lastReviewedAt, isNull);
      expect(card.level, LearningLevel.newCard);
    });

    test('times are stored as UTC', () {
      // FSRS reviewCard throws when it sees a non-UTC DateTime.
      final card = MemoryCard.create(
        type: CardType.text,
        now: DateTime(2026, 8, 1, 12), // local time
      );
      expect(card.createdAt.isUtc, isTrue);
      expect(card.dueAt.isUtc, isTrue);
      expect(card.fsrsCard.due.isUtc, isTrue);
    });

    test('the media fields exist from day one', () {
      // So adding a capture mode never needs a schema migration.
      final card = MemoryCard.create(
        type: CardType.photo,
        answer: 'a note',
        mediaPath: 'media/a.jpg',
        thumbnailPath: 'thumbnails/a.jpg',
        mediaDurationMs: 3000,
        sourceLabel: 'notes.pdf · page 1',
      );
      expect(card.mediaPath, 'media/a.jpg');
      expect(card.thumbnailPath, 'thumbnails/a.jpg');
      expect(card.mediaDurationMs, 3000);
      expect(card.sourceLabel, 'notes.pdf · page 1');
    });
  });
}
