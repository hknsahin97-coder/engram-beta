import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'accent_button.dart';

/// Empty state screen.
///
/// Tone rule: an empty state is **not a report of a shortcoming**. It says
/// "No cards yet", never "you haven't added any cards". The texts are written
/// at the call site and come from the `.arb` file.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// An emoji, shown inside a 56px accent-tint circle.
  final String icon;

  /// The title uses "voice" -- the editorial tone comes from here.
  final String title;

  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.accentTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.voice(size: 18, color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(
                size: 14,
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AccentButton.compact(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
