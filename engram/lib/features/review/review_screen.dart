import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../data/models/memory_card.dart';
import '../../domain/srs/rating.dart';
import '../../domain/srs/review_queue.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';
import '../shell/shell_controller.dart';
import 'review_card_view.dart';

/// The `Review` screen -- a vertical scroll-snap flow.
///
/// **The session is a snapshot:** the queue is taken once on entering the
/// screen and held locally. Every rating refreshes `reviewQueueProvider` (the
/// card's `dueAt` changes); watching the list live would make cards slide out
/// from under the user's feet.
///
/// **Why [isActive] exists:** this screen lives inside an `IndexedStack`, so it
/// is built even while the user is on the `Add` screen. Without knowing about
/// visibility it would capture the session in the background, while the user
/// was still adding cards, and later cards would never appear in it.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.isActive = true});

  /// Is the screen visible right now? While `false`, no session is started.
  final bool isActive;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _pageController = PageController();

  List<MemoryCard>? _session;
  final Set<int> _revealed = {};

  /// Two flags taken from the queue as the session starts. They are kept here
  /// because the provider is not consulted once a session is running.
  bool _moreThanCap = false;
  bool _showCapHint = false;

  /// The ids of cards rated in this session. The closing screen appears only
  /// once this set covers the whole session.
  final Set<int> _rated = {};

  int _currentPage = 0;

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Release the session on leaving the screen: the next time round the queue
    // is fetched again and anything added in between shows up.
    if (oldWidget.isActive && !widget.isActive) {
      _clearSession();
      ref.invalidate(reviewQueueProvider);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _clearSession() {
    _session = null;
    _revealed.clear();
    _rated.clear();
    _currentPage = 0;
  }

  void _startSession(ReviewQueue queue) {
    final cards = queue.cards;
    _moreThanCap = queue.moreThanCap;
    _showCapHint = queue.shouldShowCapHint;
    _session = List.of(cards);
    _revealed.clear();
    _rated.clear();
    _currentPage = 0;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  /// The index of the next **unrated** card after the current page.
  /// The list wraps around; `null` when none are left.
  int? _nextUnrated(List<MemoryCard> cards) {
    for (var step = 1; step <= cards.length; step++) {
      final i = (_currentPage + step) % cards.length;
      if (!_rated.contains(cards[i].id)) return i;
    }
    return null;
  }

  Future<void> _rate(MemoryCard card, Rating rating) async {
    HapticFeedback.selectionClick();
    final cards = _session!;

    setState(() => _rated.add(card.id));

    // A skipped card is not lost: we move to the next unrated card, wrapping
    // to the start if needed. Once all are done, the closing screen.
    final target = _nextUnrated(cards) ?? cards.length;

    // Wait a frame -- the closing page only exists after setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        target,
        duration: AppDuration.reveal,
        curve: Curves.easeOutCubic,
      );
    });

    // Saving does not hold up the transition; it can take a few hundred ms.
    await ref.read(reviewActionsProvider).rate(
          cardId: card.id,
          rating: rating,
        );
  }

  void _finish() {
    setState(_clearSession);
    ref.invalidate(reviewQueueProvider);
    ref.read(shellPageProvider.notifier).go(ShellPage.add);
  }

  /// The cap reminder is one-time: it is marked the moment it is shown.
  void _markCapHintShown() {
    if (!_showCapHint) return;
    _showCapHint = false;
    ref.read(reviewActionsProvider).markCapHintShown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = context.palette;
    final queue = ref.watch(reviewQueueProvider);

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        // Once the session has started, do NOT look at the provider at all.
        //
        // Why: every rating changes the card's `dueAt`, which fires
        // `watchChanges`, and `reviewQueueProvider` was briefly `loading`.
        // `when(loading: ...)` removed the whole PageView from the screen at
        // that moment, the `nextPage` animation died halfway and the session
        // collapsed -- nothing after the first card could be reviewed.
        child: _session != null
            ? _buildSession(_session!)
            : queue.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text('$e', textAlign: TextAlign.center),
                  ),
                ),
                data: (q) {
                  if (q.isEmpty) {
                    return EmptyStateView(
                      icon: '🌱',
                      title: l10n.reviewEmptyTitle,
                      message: l10n.reviewEmptySubtitle,
                      actionLabel: l10n.reviewEmptyAction,
                      onAction: () => ref
                          .read(shellPageProvider.notifier)
                          .go(ShellPage.add),
                    );
                  }
                  // Do NOT start a session while the screen is invisible -- a
                  // session captured in the background missed cards added later.
                  if (!widget.isActive) return const SizedBox.shrink();

                  // The session is built during build and used in the same
                  // frame; setState is not called because we are already in build.
                  _startSession(q);
                  return _buildSession(_session!);
                },
              ),
      ),
    );
  }

  Widget _buildSession(List<MemoryCard> cards) {
    // The closing page exists only once EVERY card has been rated. That makes
    // it impossible to reach the "you're done" screen by skipping cards; a
    // skipped card necessarily comes back round.
    final allRated = _rated.length >= cards.length;

    return Column(
      children: [
        _ProgressBar(done: _rated.length, total: cards.length),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // Pre-build the neighbouring page. By default the next card is
            // only created as it starts becoming visible, and it could look
            // empty for the first instant of the transition.
            allowImplicitScrolling: true,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: cards.length + (allRated ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == cards.length) {
                return _CompletionView(
                  onDone: _finish,
                  moreThanCap: _moreThanCap,
                  showCapHint: _showCapHint,
                  onCapHintShown: _markCapHintShown,
                );
              }
              final card = cards[i];
              return ReviewCardView(
                card: card,
                revealed: _revealed.contains(card.id),
                onReveal: () => setState(() => _revealed.add(card.id)),
                onRate: (rating) => _rate(card, rating),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The progress bar.
///
/// **It starts at 12%** (the goal-gradient effect): a bar starting from zero
/// says "you have got nowhere"; a small initial fill raises the chance of
/// carrying on. It reaches 100% when the cards run out.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  static const double _startFraction = 0.12;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ratio = total == 0 ? 0.0 : done / total;
    final value = _startFraction + (1 - _startFraction) * ratio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hairline),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: _startFraction, end: value),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 4,
            backgroundColor: palette.border,
            valueColor: const AlwaysStoppedAnimation(AppPalette.accent),
          ),
        ),
      ),
    );
  }
}

/// The closing screen -- shown when the cards run out.
///
/// Tone rule: finishing is celebrated, but nobody is told they "cleared their
/// debt". The text lives in the `.arb`: "That's it for today" / "Nothing else is due".
class _CompletionView extends StatefulWidget {
  const _CompletionView({
    required this.onDone,
    required this.moreThanCap,
    required this.showCapHint,
    required this.onCapHintShown,
  });

  final VoidCallback onDone;

  /// Whether any cards were held back from today because of the cap.
  final bool moreThanCap;

  /// Whether the cap was hit for the **first** time -- the explanation only then.
  final bool showCapHint;

  final VoidCallback onCapHintShown;

  @override
  State<_CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<_CompletionView> {
  /// Whether the reminder appears on this screen is decided **at startup**.
  ///
  /// Why it keeps its own copy: writing the "shown" flag upward rebuilds the
  /// parent and `widget.showCapHint` comes back false. Read directly, the
  /// sentence was removed in the very frame it was written -- an integration
  /// test caught it; in practice the user would never have seen the reminder.
  late final bool _showHint = widget.showCapHint;

  @override
  void initState() {
    super.initState();
    // Marked when the screen is really built: if the user left the session
    // without ever reaching the closing screen, the reminder is not spent.
    if (_showHint) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onCapHintShown());
    }
  }

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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppPalette.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('✓', style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.reviewDoneTitle,
            textAlign: TextAlign.center,
            style: AppText.voice(size: 22, color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // With the cap in effect, "nothing else left" is not true. The
            // number is still withheld -- only the existence of
            // something waiting is stated.
            widget.moreThanCap
                ? l10n.dailyLimitHintTitle
                : l10n.reviewDoneSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS(palette.textSecondary),
          ),
          // The explanatory sentence is one-time: it says where the
          // setting is, then never appears again. Repeated every time, it
          // would start to sound like "you are falling behind".
          if (_showHint) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.dailyLimitHintBody,
                textAlign: TextAlign.center,
                style: AppText.body(
                  size: 13,
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AccentButton.compact(
            label: l10n.reviewDoneAction,
            onPressed: widget.onDone,
          ),
        ],
      ),
    );
  }
}
