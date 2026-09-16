import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/share/incoming_share.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/optional_field_row.dart';
import '../../data/models/memory_card.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';
import '../shell/shell_controller.dart';
import 'save_flight.dart';

/// Text mode -- the simplest way to capture.
///
/// The zero-friction rule takes shape here: when the screen opens the cursor is
/// in the main field and the user can start typing straight away. The answer
/// field is optional and collapsed; nobody is forced to write one.
class TextPanel extends ConsumerStatefulWidget {
  const TextPanel({super.key, required this.isActive});

  /// Whether text mode is the visible page right now.
  ///
  /// Focus depends on it. `autofocus: true` looked sufficient but was not:
  /// because `PageView` pre-builds the neighbouring page, the keyboard shot up
  /// even when the app opened in **Camera** mode -- a keyboard nobody asked
  /// for, covering half the viewfinder.
  final bool isActive;

  @override
  ConsumerState<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends ConsumerState<TextPanel> {
  final _promptController = TextEditingController();
  final _answerController = TextEditingController();
  final _promptFocus = FocusNode();
  final _answerFocus = FocusNode();
  final _promptKey = GlobalKey();

  bool _answerExpanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Enabling the Save button depends on the text not being empty.
    _promptController.addListener(_onPromptChanged);
    // If the panel was built after a share arrived (PageView only made the text
    // page at that moment), content may be waiting in the mailbox.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeShared();
      if (widget.isActive) _promptFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(TextPanel old) {
    super.didUpdateWidget(old);
    if (widget.isActive == old.isActive) return;
    // Entering text mode the cursor has to be ready (zero friction); leaving
    // it, the keyboard has to close -- a keyboard left open covered half of
    // the next mode.
    if (widget.isActive) {
      _promptFocus.requestFocus();
    } else {
      _promptFocus.unfocus();
      _answerFocus.unfocus();
    }
  }

  /// Writes text shared from another app into the field.
  ///
  /// **It appends, it does not overwrite.** If a share erased an unsaved draft
  /// that would be an unrecoverable loss -- at a moment the user never chose,
  /// while they were in another app.
  void _takeShared() {
    if (!mounted) return;
    final share = ref.read(incomingShareProvider.notifier).consume();
    if (share == null) return;

    final existing = _promptController.text.trimRight();
    _promptController.text =
        existing.isEmpty ? share.text : '$existing\n\n${share.text}';
    // Cursor at the end: the user can carry on typing after the shared text.
    _promptController.selection = TextSelection.collapsed(
      offset: _promptController.text.length,
    );
    _promptFocus.requestFocus();
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _answerController.dispose();
    _promptFocus.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _onPromptChanged() => setState(() {});

  bool get _canSave => _promptController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final prompt = _promptController.text.trim();
    final answer = _answerController.text.trim();

    final card = MemoryCard.create(
      type: CardType.text,
      prompt: prompt,
      // An empty answer is stored as null -- an empty string would look like
      // "there is an answer but it is blank" and misbehave on the review screen.
      answer: answer.isEmpty ? null : answer,
    );

    await ref.read(cardRepositoryProvider).add(card);

    if (!mounted) return;

    _launchFlight();

    // Clear the fields: adding cards back to back has to flow, and the user
    // should not have to delete anything by hand after saving.
    _promptController.clear();
    _answerController.clear();
    setState(() {
      _answerExpanded = false;
      _saving = false;
    });
    _promptFocus.requestFocus();

    // The islet badge should update immediately.
    ref.invalidate(reviewQueueProvider);
  }

  /// Flying the saved card to the Library icon.
  void _launchFlight() {
    final sourceBox =
        _promptKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox = ref
        .read(libraryIconKeyProvider)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (sourceBox == null || targetBox == null) return;

    final from = sourceBox.localToGlobal(Offset.zero) & sourceBox.size;
    final to = targetBox.localToGlobal(Offset.zero) & targetBox.size;

    SaveFlight.launch(
      context: context,
      // The source box is as wide as the whole text area; it is narrowed so it
      // looks like a small card.
      from: Rect.fromCenter(
        center: from.center,
        width: 120,
        height: 60,
      ),
      to: to,
      glyph: '🎴',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = L10n.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // A share arriving while the panel is already up.
    ref.listen<IncomingShare?>(incomingShareProvider, (_, next) {
      if (next != null) _takeShared();
    });

    return SafeArea(
      child: Padding(
        // Room at the top for the chip row.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          88,
          AppSpacing.xxl,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
      // The writing area is not stuck to the top but sits slightly above the
      // middle of the screen (-0.35). Pinned to the top it ended up right under
      // the chip row and looked like an element belonging to it.
              child: Align(
                alignment: const Alignment(0, -0.35),
                child: SingleChildScrollView(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: _promptKey,
                      controller: _promptController,
                      focusNode: _promptFocus,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: AppPalette.accent,
                      cursorWidth: 2.5,
                      cursorRadius: const Radius.circular(2),
                      style: AppText.voice(
                        size: 29,
                        weight: 500,
                        color: palette.textPrimary,
                        height: 1.28,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.textPrompt,
                        hintStyle: AppText.voice(
                          size: 29,
                          weight: 500,
                          color: palette.textSecondary,
                          height: 1.28,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    OptionalFieldRow(
                      label: l10n.addAnswer,
                      optionalLabel: l10n.optional,
                      expanded: _answerExpanded,
                      onTap: () {
                        setState(() => _answerExpanded = !_answerExpanded);
                        if (_answerExpanded) _answerFocus.requestFocus();
                      },
                    ),
                    if (_answerExpanded)
                      TextField(
                        controller: _answerController,
                        focusNode: _answerFocus,
                        maxLines: 3,
                        minLines: 2,
                        cursorColor: AppPalette.accent,
                        style: AppTextStyles.bodyM(palette.textPrimary),
                        decoration: InputDecoration(
                          hintText: l10n.answerHint,
                          hintStyle:
                              AppTextStyles.bodyM(palette.textSecondary),
                          filled: true,
                          fillColor: palette.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl - 2,
                            vertical: AppSpacing.lg,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            borderSide: const BorderSide(
                              color: AppPalette.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AccentButton(
              label: l10n.save,
              onPressed: _canSave ? _save : null,
            ),
            // The shell sets `resizeToAvoidBottomInset: false` so the islet
            // does not jump with the keyboard. The cost: the layout does not
            // shrink, so the Save button ends up under the keyboard. We
            // compensate for the inset here, in this panel only.
            SizedBox(
              height: keyboard > 0
                  ? keyboard + AppSpacing.md
                  // Room for the Save button above the islet while the
                  // keyboard is closed.
                  : 96,
            ),
          ],
        ),
      ),
    );
  }
}
