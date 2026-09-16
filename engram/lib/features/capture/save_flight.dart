import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The animation that flies a saved card to the Library icon.
///
/// Why it exists: it teaches, once, **where** the thing you saved went. It is
/// the only thing that explains what the icon in the top left is -- said with
/// motion instead of a written label.
///
/// It does not block the flow: it runs in an `Overlay` and the caller does not
/// `await` it. Animations can overlap while cards are added quickly; that is fine.
abstract final class SaveFlight {
  static void launch({
    required BuildContext context,
    required Rect from,
    required Rect to,
    required String glyph,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: AppDuration.fly,
    );

    entry = OverlayEntry(
      builder: (_) => _Flight(
        animation: controller,
        from: from,
        to: to,
        glyph: glyph,
      ),
    );

    overlay.insert(entry);
    controller.forward().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }
}

class _Flight extends StatelessWidget {
  const _Flight({
    required this.animation,
    required this.from,
    required this.to,
    required this.glyph,
  });

  final Animation<double> animation;
  final Rect from;
  final Rect to;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    // easeInOutCubic: a gentle acceleration, then settling onto the icon.
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);

    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final t = curve.value;
        final rect = Rect.lerp(from, to, t)!;
        // It travels along an arc: straight-line motion is hard for the eye to
        // follow, while a slight curve makes it visible.
        final arc = -60.0 * (4 * t * (1 - t));
        return Positioned(
          left: rect.left,
          top: rect.top + arc,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: Opacity(
              // Fade at the end: on arrival it hands over to the real icon.
              opacity: t < 0.85 ? 1.0 : (1 - t) / 0.15,
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.accent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(glyph, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
