import 'package:engram/data/models/memory_card.dart';
import 'package:engram/domain/srs/review_queue.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryCard _card(CardType type, {required int overdueDays}) {
  final now = DateTime.utc(2026, 8, 1, 12);
  return MemoryCard.create(type: type, prompt: '$type-$overdueDays', now: now)
    ..dueAt = now.subtract(Duration(days: overdueDays));
}

/// As the repository hands it over: sorted most overdue first.
List<MemoryCard> _due(List<CardType> types) {
  final cards = <MemoryCard>[];
  for (var i = 0; i < types.length; i++) {
    cards.add(_card(types[i], overdueDays: types.length - i));
  }
  return cards;
}

void main() {
  group('daily cap', () {
    test('the queue is trimmed once the cap is exceeded', () {
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(40, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      expect(queue.cards.length, 25);
    });

    test('the badge never shows the raw total', () {
      // A user who sees they owe 400 cards stops opening the app.
      // The badge is min(dueCount, dailyCap).
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(400, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      expect(queue.badgeCount, 25);
    });

    test('below the cap the badge shows the real number', () {
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(7, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      expect(queue.badgeCount, 7);
      expect(queue.cards.length, 7);
    });

    test('an empty queue', () {
      final queue = ReviewQueueBuilder.build(
        due: [],
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      expect(queue.isEmpty, isTrue);
      expect(queue.badgeCount, 0);
      expect(queue.shouldShowCapHint, isFalse);
    });
  });

  group('cap reminder', () {
    test('shown the first time the cap is hit', () {
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(30, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      expect(queue.shouldShowCapHint, isTrue);
    });

    test('not shown again once it has been shown', () {
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(30, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: true,
      );

      expect(queue.shouldShowCapHint, isFalse);
    });

    test('not shown unless the cap is actually hit', () {
      final queue = ReviewQueueBuilder.build(
        due: _due(List.filled(25, CardType.text)),
        dailyCap: 25,
        capHintAlreadyShown: false,
      );

      // Exactly the cap many cards, but not exceeded -- no reason to warn.
      expect(queue.shouldShowCapHint, isFalse);
    });
  });

  group('media interleaving', () {
    test('cards of the same type do not arrive back to back', () {
      final mixed = ReviewQueueBuilder.interleaveByType([
        _card(CardType.photo, overdueDays: 6),
        _card(CardType.photo, overdueDays: 5),
        _card(CardType.photo, overdueDays: 4),
        _card(CardType.text, overdueDays: 3),
        _card(CardType.text, overdueDays: 2),
        _card(CardType.audio, overdueDays: 1),
      ]);

      for (var i = 1; i < mixed.length; i++) {
        expect(mixed[i].type, isNot(mixed[i - 1].type),
            reason: 'the same type repeated at position $i');
      }
    });

    test('with a single type the order is untouched', () {
      final original = [
        _card(CardType.text, overdueDays: 3),
        _card(CardType.text, overdueDays: 2),
        _card(CardType.text, overdueDays: 1),
      ];

      final result = ReviewQueueBuilder.interleaveByType(original);
      expect(result.map((c) => c.prompt), original.map((c) => c.prompt));
    });

    test('the overdue order within a type is preserved', () {
      final result = ReviewQueueBuilder.interleaveByType([
        _card(CardType.photo, overdueDays: 9),
        _card(CardType.photo, overdueDays: 4),
        _card(CardType.text, overdueDays: 8),
        _card(CardType.text, overdueDays: 2),
      ]);

      final photos =
          result.where((c) => c.type == CardType.photo).map((c) => c.prompt);
      expect(photos, ['CardType.photo-9', 'CardType.photo-4']);
    });

    test('no card is lost', () {
      final input = [
        _card(CardType.photo, overdueDays: 5),
        _card(CardType.text, overdueDays: 4),
        _card(CardType.audio, overdueDays: 3),
        _card(CardType.video, overdueDays: 2),
        _card(CardType.photo, overdueDays: 1),
      ];

      final result = ReviewQueueBuilder.interleaveByType(input);
      expect(result.length, input.length);
      expect(result.map((c) => c.prompt).toSet(),
          input.map((c) => c.prompt).toSet());
    });

    test('a majority type does not pile up at the end', () {
      // This is why the largest bucket is preferred: otherwise, in a queue of
      // 8 photos and 2 texts, the last 6 cards would all be photos.
      final result = ReviewQueueBuilder.interleaveByType([
        for (var i = 8; i > 0; i--) _card(CardType.photo, overdueDays: i),
        _card(CardType.text, overdueDays: 10),
        _card(CardType.text, overdueDays: 9),
      ]);

      final lastFour = result.sublist(result.length - 4);
      expect(lastFour.every((c) => c.type == CardType.photo), isTrue,
          reason: 'the last block may be photos because the texts ran out');
      // The texts should be spread across the first half.
      final textPositions = <int>[];
      for (var i = 0; i < result.length; i++) {
        if (result[i].type == CardType.text) textPositions.add(i);
      }
      expect(textPositions.first, lessThan(3));
    });
  });

  test('the cap is applied BEFORE interleaving', () {
    // In the other order, interleaving would pull less-overdue cards forward
    // and destroy the cap's meaning of "take the most overdue".
    final due = [
      _card(CardType.text, overdueDays: 10),
      _card(CardType.text, overdueDays: 9),
      _card(CardType.photo, overdueDays: 1),
    ];

    final queue = ReviewQueueBuilder.build(
      due: due,
      dailyCap: 2,
      capHintAlreadyShown: true,
    );

    expect(queue.cards.length, 2);
    expect(
      queue.cards.map((c) => c.prompt).toSet(),
      {'CardType.text-10', 'CardType.text-9'},
      reason: 'the two most overdue cards should have been selected',
    );
  });

  group('cap signal', () {
    test('no "there is more" unless the cap was exceeded', () {
      final q = ReviewQueueBuilder.build(
        due: _due(List.filled(3, CardType.text)),
        dailyCap: 10,
        capHintAlreadyShown: false,
      );
      expect(q.moreThanCap, isFalse);
      expect(q.shouldShowCapHint, isFalse);
    });

    test('"there is more" is right when the cap was exceeded, but no number', () {
      // The closing screen says "nothing else left"; with the cap in effect that
      // is not true. Even so, how many cards are waiting appears nowhere.
      final q = ReviewQueueBuilder.build(
        due: _due(List.filled(30, CardType.text)),
        dailyCap: 10,
        capHintAlreadyShown: false,
      );
      expect(q.moreThanCap, isTrue);
      expect(q.cards, hasLength(10));
      expect(q.badgeCount, 10);
    });

    test('the reminder does not reappear once it has been shown', () {
      final q = ReviewQueueBuilder.build(
        due: _due(List.filled(30, CardType.text)),
        dailyCap: 10,
        capHintAlreadyShown: true,
      );
      // "There is more" is permanent (always true), while the explanatory
      // sentence is one-time.
      expect(q.moreThanCap, isTrue);
      expect(q.shouldShowCapHint, isFalse);
    });
  });
}
