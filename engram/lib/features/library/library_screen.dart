import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/card_media.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../data/models/memory_card.dart';
import '../../data/repositories/card_repository.dart';
import '../../domain/srs/learning_level.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_sheet.dart';
import 'card_detail_sheet.dart';
import 'library_controller.dart';

/// The Library -- the one place where everything saved can be seen.
///
/// It opens full screen, not as a sheet: a two-column grid, sorting and
/// filtering need more room than a sheet can give.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final cards = ref.watch(libraryCardsProvider);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(),
            const _Summary(),
            const _SearchField(),
            _FilterBar(filter: filter),
            Expanded(
              child: cards.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  if (list.isEmpty) {
                    // An exit route while filtered: otherwise the user is left
                    // on an empty screen having to work out which filter
                    // emptied it.
                    return EmptyStateView(
                      icon: '🎴',
                      title: filter.isFiltered
                          ? l10n.filterNoMatch
                          : l10n.libraryEmptyTitle,
                      message: filter.isFiltered
                          ? ''
                          : l10n.libraryEmptySubtitle,
                      actionLabel:
                          filter.isFiltered ? l10n.clearFilters : null,
                      onAction: filter.isFiltered
                          ? () => ref
                              .read(libraryFilterProvider.notifier)
                              .clear()
                          : null,
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxs,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      // Card text runs up to 3 lines.
                      childAspectRatio: 0.98,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _LibraryCard(card: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: palette.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.libraryTitle,
              style: AppText.voice(size: 17, color: palette.textPrimary),
            ),
          ),
          InkWell(
            onTap: () => SettingsSheet.show(context),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surface,
                border: Border.all(color: palette.border),
              ),
              child: const Text('⚙️', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The header summary: total cards, overall success, well-known cards.
///
/// **There is no streak box.**
class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final stats = ref.watch(libraryStatsProvider).valueOrNull;

    Widget box(String value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppText.body(
                size: 19,
                weight: 700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.body(size: 12, color: palette.textSecondary),
            ),
          ],
        );

    final accuracy = stats?.accuracy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl - 2,
      ),
      child: Row(
        children: [
          box('${stats?.totalCards ?? 0}', l10n.libraryStatTotal),
          const SizedBox(width: AppSpacing.xxl),
          // With no reviews, a dash instead of a percentage: showing "0%
          // success" would be both misleading and discouraging.
          box(
            accuracy == null ? '—' : '${(accuracy * 100).round()}%',
            l10n.libraryStatAccuracy,
          ),
          const SizedBox(width: AppSpacing.xxl),
          box('${stats?.knownCards ?? 0}', l10n.libraryStatKnown),
        ],
      ),
    );
  }
}

/// The search box.
///
/// It sits **above** the filter bar: search is the real tool for narrowing the
/// cards, with the filters secondary beside it. The two work together --
/// searching does not reset the selected type.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The state lives in the provider so an old search does not remain in the
    // box when the Library is closed and reopened; the box only reflects it.
    _controller.text = ref.read(libraryFilterProvider).query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final hasText = _controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ref.read(libraryFilterProvider.notifier).setQuery(value);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        style: AppText.body(size: 14, color: palette.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.librarySearchHint,
          hintStyle: AppText.body(size: 14, color: palette.textSecondary),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: palette.textSecondary,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          // The clear button only appears while there is text: a close icon on
          // an empty box is a control with nothing to do.
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
                  onPressed: () {
                    _controller.clear();
                    ref.read(libraryFilterProvider.notifier).setQuery('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppPalette.accent),
          ),
        ),
      ),
    );
  }
}

/// The sort selector plus the type and level filters.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final LibraryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final controller = ref.read(libraryFilterProvider.notifier);

    String sortLabel(CardSort s) => switch (s) {
          CardSort.newest => l10n.sortNewest,
          CardSort.weakest => l10n.sortWeakest,
          CardSort.nextReview => l10n.sortNextReview,
        };

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          _Pill(
            label: '↕ ${sortLabel(filter.sort)}',
            selected: true,
            onTap: () async {
              final picked = await _pickSort(context, filter.sort, sortLabel);
              if (picked != null) controller.setSort(picked);
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          for (final level in LearningLevel.values) ...[
            _Pill(
              label: switch (level) {
                LearningLevel.newCard => l10n.levelNew,
                LearningLevel.weak => l10n.levelWeak,
                LearningLevel.learning => l10n.levelLearning,
                LearningLevel.known => l10n.levelKnown,
              },
              selected: filter.levels.contains(level),
              onTap: () => controller.toggleLevel(level),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          // Text is here too: without it, filtering down to text cards would
          // be impossible, and someone whose only card is text would see an
          // empty screen on any type pill and assume the filter is broken.
          //
          // Labels are emoji plus text: the emoji alone did not say what it was.
          for (final type in CardType.values) ...[
            _Pill(
              label: switch (type) {
                CardType.text => '✏️ ${l10n.modeText}',
                CardType.photo => '📷 ${l10n.modeCamera}',
                CardType.video => '🎬 Video',
                CardType.audio => '🎙️ ${l10n.modeAudio}',
                CardType.pdfSnippet => '📄 PDF',
              },
              selected: filter.types.contains(type),
              onTap: () => controller.toggleType(type),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  Future<CardSort?> _pickSort(
    BuildContext context,
    CardSort current,
    String Function(CardSort) labelOf,
  ) {
    return showModalBottomSheet<CardSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final sort in CardSort.values)
              ListTile(
                title: Text(labelOf(sort)),
                trailing: sort == current
                    ? const Icon(Icons.check, color: AppPalette.accent)
                    : null,
                onTap: () => Navigator.pop(context, sort),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: selected ? palette.accentTint : palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppPalette.accent : palette.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body(
              size: 13,
              weight: selected ? 600 : 500,
              color: selected ? AppPalette.accent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

String? _durationLabel(MemoryCard card) {
  final ms = card.mediaDurationMs;
  if (ms == null) return null;
  final d = Duration(milliseconds: ms);
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);

    final levelLabel = switch (card.level) {
      LearningLevel.newCard => l10n.levelNew,
      LearningLevel.weak => l10n.levelWeak,
      LearningLevel.learning => l10n.levelLearning,
      LearningLevel.known => l10n.levelKnown,
    };

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl + 2),
      child: InkWell(
        onTap: () => CardDetailSheet.show(context, card),
        borderRadius: BorderRadius.circular(AppRadius.xl + 2),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl - 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl + 2),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accentTint,
                ),
                child: Text(
                  switch (card.type) {
                    CardType.text => '✏️',
                    CardType.photo => '📷',
                    CardType.video => '🎬',
                    CardType.audio => '🎙️',
                    CardType.pdfSnippet => '📄',
                  },
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Expanded(
                // On a media card the face of the card is the image itself; on
                // a text card it is the writing. With neither, the card would
                // look empty, so the note (`answer`) is used as a fallback.
                // Video is not played in the grid either: twenty players in a
                // twenty-card grid would exhaust memory. A video card sits
                // there with its icon and duration, and plays in the detail.
                child: (card.mediaPath ?? '').isNotEmpty &&
                        card.type != CardType.audio &&
                        card.type != CardType.video
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox.expand(
                          child: CardMedia(
                            mediaPath: card.mediaPath,
                            thumbnailPath: card.thumbnailPath,
                            preferThumbnail: true,
                          ),
                        ),
                      )
                    : Text(
                        // An audio card with no note has no text to show; a
                        // duration beats nothing and is enough to tell it apart.
                        card.prompt ??
                            card.answer ??
                            _durationLabel(card) ??
                            '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 13.5,
                          weight: 600,
                          color: palette.textPrimary,
                          height: 1.32,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                levelLabel,
                style: AppText.body(size: 11, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
