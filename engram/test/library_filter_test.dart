import 'package:engram/data/models/memory_card.dart';
import 'package:engram/data/repositories/card_repository.dart';
import 'package:engram/domain/srs/learning_level.dart';
import 'package:engram/features/library/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryCard _card({
  required String prompt,
  CardType type = CardType.text,
  int reps = 0,
  int lapses = 0,
  double? stability,
}) {
  return MemoryCard.create(type: type, prompt: prompt)
    ..reps = reps
    ..lapses = lapses
    ..stability = stability;
}

void main() {
  group('LibraryFilter', () {
    test('default: no filter, newest first', () {
      const filter = LibraryFilter();
      expect(filter.sort, CardSort.newest);
      expect(filter.isFiltered, isFalse);
    });

    test('an empty set means "all", not "none"', () {
      // The distinction matters: reading an empty set as "no type selected"
      // would empty the screen whenever the user turned the filters off.
      const filter = LibraryFilter(types: {});
      expect(filter.isFiltered, isFalse);
    });

    test('selecting a type or a level counts as filtered', () {
      expect(
        const LibraryFilter(types: {CardType.audio}).isFiltered,
        isTrue,
      );
      expect(
        const LibraryFilter(levels: {LearningLevel.weak}).isFiltered,
        isTrue,
      );
    });

    test('copyWith preserves the other fields', () {
      const base = LibraryFilter(
        sort: CardSort.weakest,
        types: {CardType.photo},
      );
      final next = base.copyWith(levels: {LearningLevel.known});

      expect(next.sort, CardSort.weakest);
      expect(next.types, {CardType.photo});
      expect(next.levels, {LearningLevel.known});
    });
  });

  group('level filter', () {
    // The level filter is deliberately not in the repository layer: level is not
    // a database column but a domain concept computed from the card's fields.
    // These tests guard that the filtering uses the right definition.
    late List<MemoryCard> cards;

    setUp(() {
      cards = [
        _card(prompt: 'new'),
        _card(prompt: 'weak', reps: 20, lapses: 5, stability: 40),
        _card(prompt: 'learning', reps: 5, stability: 10),
        _card(prompt: 'known', reps: 5, stability: 40),
      ];
    });

    List<String> filterBy(Set<LearningLevel> levels) => cards
        .where((c) => levels.isEmpty || levels.contains(c.level))
        .map((c) => c.prompt!)
        .toList();

    test('a single level', () {
      expect(filterBy({LearningLevel.known}), ['known']);
      expect(filterBy({LearningLevel.newCard}), ['new']);
    });

    test('an often-forgotten card counts as Weak despite high stability', () {
      // The "weak" card has 40 days of stability -- alone it would be Known.
      expect(filterBy({LearningLevel.weak}), ['weak']);
      expect(filterBy({LearningLevel.known}), isNot(contains('weak')));
    });

    test('several levels behave like a union', () {
      expect(
        filterBy({LearningLevel.newCard, LearningLevel.known}),
        ['new', 'known'],
      );
    });

    test('an empty set lets everything through', () {
      expect(filterBy({}).length, 4);
    });
  });

  group('search', () {
    MemoryCard card({String? prompt, String? answer, String? source}) =>
        MemoryCard.create(
          type: CardType.text,
          prompt: prompt,
          answer: answer,
          sourceLabel: source,
        );

    test('an empty query lets every card through', () {
      // With the search box empty, the Library has to show the full list.
      expect(cardMatchesQuery(card(prompt: 'anything'), ''), isTrue);
      expect(cardMatchesQuery(card(prompt: 'anything'), '   '), isTrue);
    });

    test('it searches both the question and the answer', () {
      // Users often remember the answer rather than the question.
      expect(cardMatchesQuery(card(prompt: 'mitochondria'), 'mito'), isTrue);
      expect(
        cardMatchesQuery(card(prompt: 'x', answer: 'energy of the cell'), 'energy'),
        isTrue,
      );
    });

    test('it is case-insensitive', () {
      expect(cardMatchesQuery(card(prompt: 'Mitochondria'), 'MITO'), isTrue);
    });

    test('the PDF source is searchable too', () {
      // Typing "biology-notes.pdf" to find the excerpts taken from that
      // document is a natural expectation.
      expect(
        cardMatchesQuery(card(source: 'biology-notes.pdf · page 3'), 'biology'),
        isTrue,
      );
    });

    test('a non-matching card is left out', () {
      expect(cardMatchesQuery(card(prompt: 'mitochondria'), 'ribosome'), isFalse);
    });

    test('a search counts together with the filters', () {
      // isFiltered drives the "show everything" exit on an empty screen; that
      // exit has to appear on a screen emptied by a search too.
      const withQuery = LibraryFilter(query: 'abc');
      expect(withQuery.isFiltered, isTrue);
      expect(const LibraryFilter().isFiltered, isFalse);
    });

    test('copyWith preserves the search text', () {
      // Choosing a type must not reset the search: the two work together.
      const filter = LibraryFilter(query: 'abc');
      final withType = filter.copyWith(types: {CardType.photo});
      expect(withType.query, 'abc');
      expect(withType.types, {CardType.photo});
    });
  });
}
