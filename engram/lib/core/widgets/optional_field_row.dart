import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A row that reveals a hidden field, "+ Add answer" style.
///
/// This component carries the zero-friction decision: fields such as answer and
/// note are **optional** and start collapsed. The faint "optional" label on the
/// right says so -- the user should see that leaving a field empty is not a
/// shortcoming; no blaming language.
class OptionalFieldRow extends StatelessWidget {
  const OptionalFieldRow({
    super.key,
    required this.label,
    required this.onTap,
    this.optionalLabel,
    this.expanded = false,
    this.onViewfinder = false,
  });

  final String label;
  final VoidCallback onTap;

  /// The faint label on the right (e.g. "optional"). Hidden when `null`.
  final String? optionalLabel;

  /// While open, a minus is shown instead of a plus.
  final bool expanded;

  /// Does it sit on the viewfinder surface (like the photo confirmation
  /// screen)? Theme colours do not apply there -- the surface stays dark even
  /// in the light theme, and the text has to follow.
  final bool onViewfinder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelColor =
        onViewfinder ? ViewfinderColors.textSecondary : palette.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: 2,
        ),
        child: Row(
          children: [
            // The sign is in the accent colour and heavier -- the rest of the
            // row is secondary text. This is the one emphasis.
            Text(
              expanded ? '−' : '+',
              style: AppText.body(
                size: 14,
                weight: 700,
                color: AppPalette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppText.body(size: 14, weight: 500, color: labelColor),
            ),
            if (optionalLabel != null) ...[
              const Spacer(),
              Opacity(
                opacity: 0.6,
                child: Text(
                  optionalLabel!,
                  style: AppText.body(size: 12, color: labelColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
