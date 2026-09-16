import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Primary action button -- accent ground, white text.
///
/// It comes in two sizes:
/// - [AccentButton]: full width, 16px/600, padding 18, radius 16
/// - [AccentButton.compact]: sized to content, 14px/600, padding 12/22,
///   radius 14
///
/// The accent is fixed across themes, so this button looks the same in both.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  /// The small variant, used in places such as an empty state.
  const AccentButton.compact({
    super.key,
    required this.label,
    required this.onPressed,
  }) : expand = false;

  final String label;

  /// When `null`, the button renders as disabled.
  final VoidCallback? onPressed;

  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = expand ? AppRadius.xl : AppRadius.lg;

    final child = Material(
      color: enabled
          ? AppPalette.accent
          // While disabled we use the tint rather than fading the accent;
          // a translucent accent muddies against whatever sits behind it.
          : context.palette.accentTint,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: expand
              ? const EdgeInsets.symmetric(vertical: AppSpacing.xl)
              : const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.xxl - 2,
                ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: (expand
                    ? AppTextStyles.button(AppPalette.accentText)
                    : AppText.body(
                        size: 14,
                        weight: 600,
                        color: AppPalette.accentText,
                      ))
                .copyWith(
              color: enabled
                  ? AppPalette.accentText
                  : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
