import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '../shell/capture_mode.dart';

/// The capture mode selector.
///
/// Tapping a chip and swiping the panels both change the mode -- the two are
/// bound to the same piece of state.
///
/// Colours follow the surface: white tones over the viewfinder (dark and
/// theme-neutral), theme colours in text mode. Hence the [onViewfinder]
/// parameter -- `context.palette` cannot be trusted, the viewfinder ignores the theme.
class ModeChips extends StatelessWidget {
  const ModeChips({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onViewfinder,
  });

  final CaptureMode selected;
  final ValueChanged<CaptureMode> onSelected;
  final bool onViewfinder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);

    final labels = {
      CaptureMode.camera: '📷 ${l10n.modeCamera}',
      CaptureMode.text: '✏️ ${l10n.modeText}',
      CaptureMode.import: '📥 ${l10n.modeImport}',
      CaptureMode.audio: '🎙️ ${l10n.modeAudio}',
    };

    // The mode selector is a **tool**, not the subject of the screen. On a
    // filled surface with a border it drew more attention than the writing
    // area, so it is faded: a translucent ground and an overall drop in
    // opacity. The active chip is dimmed too -- enough to tell it apart, not
    // enough to shout.
    return Opacity(
      opacity: onViewfinder ? 1 : 0.78,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: onViewfinder
              ? const Color(0x24FFFFFF) // rgba(255,255,255,0.14)
              : palette.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: onViewfinder
              ? null
              : Border.all(color: palette.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in CaptureMode.values) ...[
              if (mode != CaptureMode.values.first)
                const SizedBox(width: AppSpacing.xxs),
              _Chip(
                label: labels[mode]!,
                active: mode == selected,
                onViewfinder: onViewfinder,
                onTap: () => onSelected(mode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onViewfinder,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool onViewfinder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Over the viewfinder the active chip is a white ground with dark text; on the theme, the accent.
    final (background, foreground) = switch ((active, onViewfinder)) {
      (true, true) => (Colors.white, const Color(0xFF0D0D0F)),
      (true, false) => (AppPalette.accent, AppPalette.accentText),
      (false, true) => (Colors.transparent, const Color(0xBFFFFFFF)),
      (false, false) => (Colors.transparent, palette.textSecondary),
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppDuration.normal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 13,
              weight: active ? 600 : 500,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
