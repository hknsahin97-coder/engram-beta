import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/share/incoming_share.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/capture_mode.dart';
import '../shell/shell_controller.dart';
import '../library/library_screen.dart';
import 'audio_panel.dart';
import 'camera_panel.dart';
import 'import_panel.dart';
import 'mode_chips.dart';
import 'text_panel.dart';

/// The `Add` screen: a four-mode horizontal swiper plus the chip row on top.
///
/// Tapping a chip and swiping are bound to the same state; both work.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late final PageController _controller;

  /// The mode selector is a tool; once the choice is made it should stop being
  /// the subject of the screen. Left untouched it fades further -- still in
  /// place, still tappable, but leaving attention to the capture area.
  static const Duration _dimAfter = Duration(milliseconds: 2500);
  static const double _dimmedOpacity = 0.22;

  bool _chipsDimmed = false;
  Timer? _dimTimer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: ref.read(captureModeProvider).pageIndex,
    );
    _wakeChips();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Makes the chip row fully visible and resets the fade timer.
  void _wakeChips() {
    _dimTimer?.cancel();
    if (_chipsDimmed) setState(() => _chipsDimmed = false);
    _dimTimer = Timer(_dimAfter, () {
      if (mounted) setState(() => _chipsDimmed = true);
    });
  }

  void _onChipTapped(CaptureMode mode) {
    _wakeChips();
    // Tapping a chip moves the swiper too -- two inputs driving one state.
    _controller.animateToPage(
      mode.pageIndex,
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
    );
  }

  /// Shared content is met in text mode: whatever mode the app was left in,
  /// someone who picks "Share -> Engram" in another app should land on an open
  /// writing area.
  ///
  /// [TextPanel] owns the text itself; this only takes them there.
  void _goToSharedText() {
    ref.read(shellPageProvider.notifier).go(ShellPage.add);
    _wakeChips();
    if (_controller.hasClients) {
      _controller.animateToPage(
        CaptureMode.text.pageIndex,
        duration: AppDuration.normal,
        curve: Curves.easeOutCubic,
      );
    } else {
      // If the page is not attached yet (the share arrived before the first
      // frame) there can be no animation. We set the mode and jump on the next
      // frame -- changing the mode alone is not enough, PageView would stay on
      // `initialPage` and the chip would disagree with the visible page.
      ref.read(captureModeProvider.notifier).select(CaptureMode.text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(CaptureMode.text.pageIndex);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(captureModeProvider);
    final onViewfinder = mode.usesViewfinder;

    ref.listen<IncomingShare?>(incomingShareProvider, (_, next) {
      if (next != null) _goToSharedText();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The viewfinder is always dark; status bar icons have to be light for it.
      // In text mode it is left to the theme.
      value: onViewfinder
          ? SystemUiOverlayStyle.light
          : (Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) {
              final next = CaptureMode.values[i];
              ref.read(captureModeProvider.notifier).select(next);
              // The mode changed: the chip row reappears, then fades again.
              _wakeChips();
            },
            children: [
              for (final m in CaptureMode.values)
                _ModePanel(mode: m, isActive: m == mode),
            ],
          ),
          _TopBar(onViewfinder: onViewfinder),
          Positioned(
            // Kept high: a writing area hanging in the middle of the screen
            // reads as secondary.
            top: 44,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _chipsDimmed ? _dimmedOpacity : 1,
                  // A slow fade: vanishing abruptly feels like something broke.
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  child: ModeChips(
                    selected: mode,
                    onSelected: _onChipTapped,
                    onViewfinder: onViewfinder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every mode carries its own ground; the grounds move with the swiper.
class _ModePanel extends StatelessWidget {
  const _ModePanel({required this.mode, required this.isActive});

  final CaptureMode mode;

  /// Whether this panel is the visible page. The camera has to know: otherwise
  /// it stays open behind the user while they type.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: mode.usesViewfinder ? ViewfinderColors.surface : null,
        color: mode.usesViewfinder ? null : palette.background,
      ),
      child: SizedBox.expand(
        child: switch (mode) {
          CaptureMode.text => TextPanel(isActive: isActive),
          CaptureMode.camera => CameraPanel(isActive: isActive),
          CaptureMode.import => ImportPanel(isActive: isActive),
          CaptureMode.audio => AudioPanel(isActive: isActive),
        },
      ),
    );
  }
}

/// The Library icon in the top left -- fixed across every screen.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onViewfinder});

  final bool onViewfinder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Positioned(
      top: 10,
      left: AppSpacing.xxl,
      right: AppSpacing.xxl,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            InkWell(
              onTap: () => LibraryScreen.open(context),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                key: ref.watch(libraryIconKeyProvider),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onViewfinder
                      ? const Color(0x2EFFFFFF)
                      : palette.surface.withValues(alpha: 0.6),
                  // With a full accent border the icon drew more attention than
                  // the writing area. It stays visible without stepping forward.
                  border: onViewfinder
                      ? null
                      : Border.all(
                          color: AppPalette.accent.withValues(alpha: 0.45),
                        ),
                ),
                child: Text('🎴', style: AppText.body(size: 14)),
              ),
            ),
            const Spacer(),
            // The top right corner belongs to the flash indicator in Camera
            // mode; here it is empty.
          ],
        ),
      ),
    );
  }
}
