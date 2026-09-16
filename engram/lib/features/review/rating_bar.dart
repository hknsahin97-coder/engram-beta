import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../domain/srs/rating.dart';
import '../../l10n/app_localizations.dart';

/// The four coloured rating buttons.
///
/// The order comes from [ratingOrder] -- left to right, "did not remember at
/// all" to "remembered". Colours come from [RatingColors] and do not follow the
/// theme: here colour carries meaning, not decoration.
///
/// The buttons are **invisible** until the card is opened: nobody should rate
/// without seeing the answer, or they only fool themselves.
class RatingBar extends StatelessWidget {
  const RatingBar({super.key, required this.onRate, required this.visible});

  final ValueChanged<Rating> onRate;
  final bool visible;

  static Color colorOf(Rating rating) => switch (rating) {
        Rating.again => RatingColors.again,
        Rating.hard => RatingColors.hard,
        Rating.good => RatingColors.good,
        Rating.easy => RatingColors.easy,
      };

  static String labelOf(Rating rating, L10n l10n) => switch (rating) {
        Rating.again => l10n.ratingAgain,
        Rating.hard => l10n.ratingHard,
        Rating.good => l10n.ratingGood,
        Rating.easy => l10n.ratingEasy,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDuration.reveal,
        child: AnimatedSlide(
          // The buttons rise slightly as they appear.
          offset: visible ? Offset.zero : const Offset(0, 0.15),
          duration: AppDuration.reveal,
          curve: Curves.easeOutCubic,
          child: Row(
            children: [
              for (final rating in ratingOrder) ...[
                if (rating != ratingOrder.first)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _RateButton(
                    color: colorOf(rating),
                    label: labelOf(rating, l10n),
                    onTap: () => onRate(rating),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          // Android's recommended minimum touch target is 48dp.
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xxs,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12.5,
              weight: 600,
              // White is unreadable on the yellow; RatingColors knows this.
              color: RatingColors.textOn(color),
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
