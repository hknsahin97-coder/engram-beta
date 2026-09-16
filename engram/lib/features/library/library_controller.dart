import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/memory_card.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../domain/srs/learning_level.dart';

/// Library filter state.
class LibraryFilter {
  const LibraryFilter({
    this.sort = CardSort.newest,
    this.types = const {},
    this.levels = const {},
    this.query = '',
  });

  final CardSort sort;

  /// An empty set means no filter (everything).
  final Set<CardType> types;
  final Set<LearningLevel> levels;

  /// The search text. It works **together** with the filters: searching
  /// does not reset the selected type or level.
  final String query;

  bool get isFiltered =>
      types.isNotEmpty || levels.isNotEmpty || query.trim().isNotEmpty;

  LibraryFilter copyWith({
    CardSort? sort,
    Set<CardType>? types,
    Set<LearningLevel>? levels,
    String? query,
  }) =>
      LibraryFilter(
        sort: sort ?? this.sort,
        types: types ?? this.types,
        levels: levels ?? this.levels,
        query: query ?? this.query,
      );
}

/// Whether a card matches the search text.
///
/// It searches `prompt` **and** `answer`: users often remember the answer, not
/// the question. Case-insensitive -- nobody thinks about capitals while typing
/// into a search box.
///
/// The `sourceLabel` of media cards is in scope too: typing "biology-notes.pdf"
/// to find the excerpts taken from that PDF is a natural expectation.
bool cardMatchesQuery(MemoryCard card, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;

  for (final field in [card.prompt, card.answer, card.sourceLabel]) {
    if (field != null && field.toLowerCase().contains(needle)) return true;
  }
  return false;
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterController, LibraryFilter>(
  LibraryFilterController.new,
);

class LibraryFilterController extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setSort(CardSort sort) => state = state.copyWith(sort: sort);

  void toggleType(CardType type) {
    final next = Set<CardType>.from(state.types);
    next.contains(type) ? next.remove(type) : next.add(type);
    state = state.copyWith(types: next);
  }

  void toggleLevel(LearningLevel level) {
    final next = Set<LearningLevel>.from(state.levels);
    next.contains(level) ? next.remove(level) : next.add(level);
    state = state.copyWith(levels: next);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  /// The "show everything" exit from an empty screen: it resets everything
  /// except the sort -- search included, or the user would clear the filters
  /// and still be left on an empty screen.
  void clear() => state = LibraryFilter(sort: state.sort);
}

/// Watches changes to the card table -- so the Library refreshes by itself when
/// a card is added or rated.
final _cardChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(cardRepositoryProvider).watchChanges(),
);

/// The filtered and sorted card list.
///
/// **Layer split:** the type filter and the sort go to the repository (storage
/// work), while the learning level filter is applied here. Level is not a
/// database column but a domain concept computed from the card's fields;
/// leaked into the data layer, the store would have to know domain rules.
final libraryCardsProvider = FutureProvider<List<MemoryCard>>((ref) async {
  ref.watch(_cardChangesProvider);

  final filter = ref.watch(libraryFilterProvider);
  final cards = await ref.watch(cardRepositoryProvider).list(
        sort: filter.sort,
        types: filter.types.isEmpty ? null : filter.types,
      );

  // Search is here too: text search in Isar would need a separate index, and
  // while a deck stays in the low thousands, filtering in memory is both fast
  // enough and keeps `prompt`/`answer`/`sourceLabel` in one place.
  return cards
      .where((c) => filter.levels.isEmpty || filter.levels.contains(c.level))
      .where((c) => cardMatchesQuery(c, filter.query))
      .toList();
});

/// The three boxes in the header summary. **Unaffected** by the filters --
/// a summary describes the whole deck, not the current view.
final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  ref.watch(_cardChangesProvider);
  return ref.watch(cardRepositoryProvider).stats();
});
