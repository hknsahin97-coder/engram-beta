import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/audio_player_bar.dart';
import '../../core/widgets/card_media.dart';
import '../../core/widgets/video_player_view.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../data/models/memory_card.dart';
import '../../domain/srs/learning_level.dart';
import '../../l10n/app_localizations.dart';

/// Card detail -- an editorial layout.
///
/// The design intent: a card is presented as a **quotation**, not as a database
/// row. A small grey "QUESTION" label and the question at the top, below them a
/// large quotation mark and the answer in Fraunces. The user's own words are
/// the subject of the page, not the interface.
class CardDetailSheet extends StatelessWidget {
  const CardDetailSheet({super.key, required this.card});

  final MemoryCard card;

  static Future<void> show(BuildContext context, MemoryCard card) =>
      SheetScaffold.show(context: context, child: CardDetailSheet(card: card));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final hasAnswer = (card.answer ?? '').trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // An audio card has to be playable, otherwise the detail page shows
          // none of the card's content at all.
          if (card.type == CardType.audio && (card.mediaPath ?? '').isNotEmpty) ...[
            _AudioRow(card: card),
            const SizedBox(height: AppSpacing.xl),
          ]
          else if (card.type == CardType.video &&
              (card.mediaPath ?? '').isNotEmpty) ...[
            _VideoRow(card: card),
            const SizedBox(height: AppSpacing.xl),
          ]
          // On a media card the image comes first: that is the card itself,
          // not the statistics below it.
          else if ((card.mediaPath ?? '').isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SizedBox(
                  width: double.infinity,
                  child: CardMedia(
                    mediaPath: card.mediaPath,
                    thumbnailPath: card.thumbnailPath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if ((card.prompt ?? '').trim().isNotEmpty) ...[
          Text(
            l10n.cardDetailQuestion,
            style: AppText.body(
              size: 11,
              weight: 700,
              color: palette.textSecondary,
              letterSpacing: 0.88,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            card.prompt ?? '',
            style: AppText.body(
              size: 14,
              weight: 500,
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          ],
          if (hasAnswer) ...[
            const SizedBox(height: AppSpacing.sm),
            // The quotation mark is decorative: it says the answer is a quote.
            // The small offset lets the mark lean into the answer.
            Transform.translate(
              offset: const Offset(0, 8),
              child: Text(
                '“',
                style: AppText.voice(
                  size: 46,
                  color: AppPalette.accent.withValues(alpha: 0.32),
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xl - 2),
              child: Text(
                card.answer!,
                style: AppText.voice(
                  size: 27,
                  color: palette.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl - 4),
          _StatGrid(card: card),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _AudioRow extends ConsumerWidget {
  const _AudioRow({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStoreProvider).resolve(card.mediaPath!);
    return AudioPlayerBar(key: ValueKey(card.id), path: file.path);
  }
}

class _VideoRow extends ConsumerWidget {
  const _VideoRow({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStoreProvider).resolve(card.mediaPath!);
    return VideoPlayerView(
      key: ValueKey(card.id),
      path: file.path,
      maxHeight: 260,
    );
  }
}

/// Four statistic boxes. The first is emphasised (accent tint).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final accuracy = card.accuracy;

    final boxes = <(String, String)>[
      (
        // With no reviews yet, showing "0%" would be misleading and blaming.
        accuracy == null ? '—' : '${(accuracy * 100).round()}%',
        l10n.cardStatAccuracy,
      ),
      ('${card.reps}', l10n.cardStatReviews),
      (
        card.lastReviewedAt == null
            ? l10n.neverReviewed
            : _relativeDays(card.lastReviewedAt!),
        l10n.cardStatLastSeen,
      ),
      (_dueLabel(card.dueAt, l10n), l10n.cardStatNextReview),
    ];

    // A fixed aspect-ratio GridView is not used: at 360dp width the box height
    // came out about 3px short of the content and overflowed. Raising the ratio
    // would have rescued only this screen -- a user with a larger text scale
    // would still overflow. With IntrinsicHeight the two boxes in a row are
    // equal in height but grow **with their content**.
    Widget row(int a, int b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatBox(
                  value: boxes[a].$1,
                  label: boxes[a].$2,
                  highlighted: a == 0,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StatBox(
                  value: boxes[b].$1,
                  label: boxes[b].$2,
                  highlighted: b == 0,
                ),
              ),
            ],
          ),
        );

    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: AppSpacing.lg),
        row(2, 3),
      ],
    );
  }

  static String _relativeDays(DateTime when) {
    final days = DateTime.now().toUtc().difference(when.toUtc()).inDays;
    if (days <= 0) return 'today';
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  static String _dueLabel(DateTime due, L10n l10n) {
    final days = due.toUtc().difference(DateTime.now().toUtc()).inDays;
    if (days <= 0) return l10n.dueNow;
    return days == 1 ? 'in 1 day' : 'in $days days';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.highlighted,
  });

  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: highlighted ? palette.accentTint : palette.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppText.body(
              size: 17,
              weight: 700,
              color: highlighted ? AppPalette.accent : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.body(size: 11.5, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
