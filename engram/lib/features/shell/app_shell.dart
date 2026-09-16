import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/share/incoming_share.dart';
import '../../domain/notifications/notification_controller.dart';
import '../../l10n/app_localizations.dart';
import '../capture/capture_screen.dart';
import '../notifications/notification_texts.dart';
import '../review/review_screen.dart';
import 'review_islet.dart';
import 'shell_controller.dart';

/// The app's shell: two **equal** primary screens with the islet floating over them.
///
/// There is **no swipe** between `Add` and `Review` -- the only transition is
/// the islet. A swipe would collide with the horizontal mode swiper inside
/// `Add`, and the user could not predict what a gesture would do.
///
/// Both screens are kept alive inside an `IndexedStack`: going to `Review` and
/// back must not lose typed text or an open camera. That is why `ReviewScreen`
/// takes its visibility as a parameter.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onOpened();
      _wireShare();
    });
  }

  /// Content shared from another app.
  ///
  /// There are two routes and both are needed: if the app **was opened by a
  /// share** the native side holds it ([ShareChannel.takeInitial]), and if it
  /// is **already open** the share arrives directly ([ShareChannel.listen]).
  /// Wire up only one and half the shares disappear.
  Future<void> _wireShare() async {
    final channel = ref.read(shareChannelProvider);
    channel.listen((share) {
      if (mounted) ref.read(incomingShareProvider.notifier).receive(share);
    });

    final initial = await channel.takeInitial();
    if (initial != null && mounted) {
      ref.read(incomingShareProvider.notifier).receive(initial);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Replan on returning to the foreground too: if the user has been in today,
    // today's notification should be cancelled.
    if (state == AppLifecycleState.resumed) _onOpened();
  }

  void _onOpened() {
    if (!mounted) return;
    // The notification plan refreshes quietly in the background; nobody waits.
    ref
        .read(notificationControllerProvider)
        .onAppOpened(notificationTextsOf(L10n.of(context)));
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(shellPageProvider);

    return Scaffold(
      // The islet must not be pushed up when the keyboard opens; the capture
      // area manages its own scrolling.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: page.index,
            children: [
              const CaptureScreen(),
              // Visibility is passed down: IndexedStack builds both screens,
              // and without knowing this ReviewScreen captures the session in
              // the background and misses cards added afterwards.
              ReviewScreen(isActive: page == ShellPage.review),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Center(child: ReviewIslet()),
            ),
          ),
        ],
      ),
    );
  }
}
