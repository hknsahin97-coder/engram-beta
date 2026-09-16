import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/audio_player_bar.dart';
import '../../core/widgets/card_media.dart';
import '../../core/widgets/video_player_view.dart';
import '../../data/models/memory_card.dart';
import '../../domain/srs/rating.dart';
import '../../l10n/app_localizations.dart';
import 'rating_bar.dart';

/// A single card in the review flow.
///
/// There are two behaviours:
/// - **A card with an answer:** tap to reveal the answer and the rating buttons.
/// - **A card without one:** there is no answer to show, so a tap opens the
///   rating directly and the hint becomes "Do you remember?". Making answers
///   compulsory would undo the zero-friction decision.
class ReviewCardView extends StatelessWidget {
  const ReviewCardView({
    super.key,
    required this.card,
    required this.revealed,
    required this.onReveal,
    required this.onRate,
  });

  final MemoryCard card;
  final bool revealed;
  final VoidCallback onReveal;
  final ValueChanged<Rating> onRate;

  bool get _hasAnswer => (card.answer ?? '').trim().isNotEmpty;

  bool get _hasMedia => (card.mediaPath ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        96,
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: revealed ? null : onReveal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The label appears ONLY on media cards. Writing "Text"
                  // on a text card teaches nothing and is only noise.
                  if (card.type != CardType.text) ...[
                    _TypeTag(type: card.type),
                    const SizedBox(height: AppSpacing.xl - 2),
                  ],
                  // On an audio card the thing to remember is what you hear:
                  // the player is the face of the card. It does not autoplay --
                  // the review screen may have been opened in a quiet room.
                  if (card.type == CardType.audio && _hasMedia) ...[
                    _AudioFace(card: card),
                    const SizedBox(height: AppSpacing.xl - 2),
                  ]
                  // A video card: poster (first frame) plus play. The play tap
                  // belongs to the video itself; tapping the rest of the card
                  // still reveals the answer.
                  else if (card.type == CardType.video && _hasMedia) ...[
                    _VideoFace(card: card),
                    const SizedBox(height: AppSpacing.xl - 2),
                  ]
                  // On a photo card **the image is the face**: there is no
                  // question text, what you have to remember is inside the
                  // picture. Height is bounded: answer and rating sit below it.
                  else if (_hasMedia) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        child: CardMedia(
                          mediaPath: card.mediaPath,
                          thumbnailPath: card.thumbnailPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if ((card.prompt ?? '').trim().isNotEmpty)
                      const SizedBox(height: AppSpacing.xl - 2),
                  ],
                  if ((card.prompt ?? '').trim().isNotEmpty)
                    Text(
                      card.prompt!,
                      textAlign: TextAlign.center,
                      style: AppText.voice(
                        size: 25,
                        color: palette.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  if (revealed && _hasAnswer) ...[
                    const SizedBox(height: AppSpacing.xl - 2),
                    Text(
                      card.answer!,
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 19,
                        weight: 500,
                        color: AppPalette.accent,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (!revealed) ...[
                    const SizedBox(height: AppSpacing.xl - 2),
                    Text(
                      // On a media card the question is the image (or the
                      // audio) itself; "reveal the answer" would be wrong here.
                      switch (card.type) {
                        CardType.audio => l10n.reviewListenThenReveal,
                        _ when _hasMedia => l10n.reviewLookThenReveal,
                        _ when _hasAnswer => l10n.reviewTapToReveal,
                        _ => l10n.reviewTapToRemember,
                      },
                      style: AppTextStyles.bodyS(palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          RatingBar(visible: revealed, onRate: onRate),
        ],
      ),
    );
  }
}

/// The face of an audio card: the player.
///
/// The player is kept narrow so that tapping it does not block revealing the
/// answer -- tapping the rest of the card still opens it.
class _AudioFace extends ConsumerWidget {
  const _AudioFace({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStoreProvider).resolve(card.mediaPath!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AudioPlayerBar(key: ValueKey(card.id), path: file.path),
    );
  }
}

/// The face of a video card.
class _VideoFace extends ConsumerWidget {
  const _VideoFace({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStoreProvider).resolve(card.mediaPath!);
    return VideoPlayerView(
      key: ValueKey(card.id),
      path: file.path,
      maxHeight: MediaQuery.sizeOf(context).height * 0.46,
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type});

  final CardType type;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final label = switch (type) {
      CardType.photo => l10n.modeCamera,
      // The same label as in the Library filter: saying "Camera" did not
      // distinguish a video from a photo.
      CardType.video => 'Video',
      CardType.audio => l10n.modeAudio,
      CardType.pdfSnippet => l10n.modeImport,
      CardType.text => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.body(size: 11.5, weight: 600, color: AppPalette.accent),
      ),
    );
  }
}
