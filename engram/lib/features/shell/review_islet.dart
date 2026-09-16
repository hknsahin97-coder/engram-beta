import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';
import 'shell_controller.dart';

/// The floating islet -- the `Add` and `Review` transition.
///
/// Three rules:
/// - **It is never hidden.** It does not vanish on scroll and stays put on a
///   full screen. The user has to know where they are and how to get to the
///   other side at any moment.
/// - **There is no dismiss control.** If it could be closed, the user would
///   close it by accident and lose the only route to the review screen.
/// - The badge shows `min(dueCount, dailyCap)` -- never the real accumulated
///   total. That number comes from [reviewQueueProvider]; no widget
///   reaches raw `dueCount`.
class ReviewIslet extends ConsumerWidget {
  const ReviewIslet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final page = ref.watch(shellPageProvider);

    // While the queue is still loading, show it without a badge -- waiting for
    // the number would make the islet disappear for a moment.
    final badge = ref.watch(reviewQueueProvider).maybeWhen(
          data: (q) => q.badgeCount,
          orElse: () => 0,
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: '✏️ ${l10n.navAdd}',
            active: page == ShellPage.add,
            onTap: () => ref.read(shellPageProvider.notifier).go(ShellPage.add),
          ),
          const SizedBox(width: AppSpacing.xxs),
          _Segment(
            label: badge > 0
                ? '📚 ${l10n.navReviewWithCount(badge)}'
                : '📚 ${l10n.navReview}',
            active: page == ShellPage.review,
            onTap: () =>
                ref.read(shellPageProvider.notifier).go(ShellPage.review),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: active ? AppPalette.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl - 2,
            vertical: AppSpacing.sm + 2,
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 14,
              weight: active ? 600 : 500,
              // The inactive segment is faded (.55 opacity) so the active
              // one stays the single point of emphasis.
              color: active
                  ? AppPalette.accentText
                  : palette.textPrimary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
