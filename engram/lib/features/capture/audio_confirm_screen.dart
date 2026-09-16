import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/audio_player_bar.dart';
import '../../core/widgets/optional_field_row.dart';
import '../../core/widgets/waveform.dart';
import '../../data/models/memory_card.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';

/// The confirmation screen for a recording.
///
/// The same skeleton as the photo confirmation screen: preview, optional note,
/// Save. The difference is that the preview can be listened to -- nobody should
/// have to create a card **without hearing** what they just recorded.
///
/// There is no scissors (trim) here: the crop screen works on images, and
/// trimming on a waveform is a separate editor that does not exist yet.
class AudioConfirmScreen extends ConsumerStatefulWidget {
  const AudioConfirmScreen({
    super.key,
    required this.clip,
    required this.duration,
    required this.levels,
  });

  final File clip;
  final Duration duration;

  /// The real amplitudes collected while recording -- shown as a frozen
  /// waveform on the confirmation screen, to say "this is what you recorded".
  final List<double> levels;

  static Future<void> open(
    BuildContext context,
    File clip, {
    required Duration duration,
    required List<double> levels,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AudioConfirmScreen(
            clip: clip,
            duration: duration,
            levels: levels,
          ),
        ),
      );

  @override
  ConsumerState<AudioConfirmScreen> createState() =>
      _AudioConfirmScreenState();
}

class _AudioConfirmScreenState extends ConsumerState<AudioConfirmScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  bool _noteExpanded = false;
  bool _saving = false;

  /// The real duration the player read from the file; until it arrives the
  /// recording counter is used.
  Duration? _actualDuration;

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final stored = await ref.read(mediaStoreProvider).save(
            source: widget.clip,
            idHint: 'audio',
            // No thumbnail can be made from an audio file; the Library grid
            // shows an audio card with its icon.
            makeThumbnail: false,
          );

      final note = _noteController.text.trim();
      await ref.read(cardRepositoryProvider).add(
            MemoryCard.create(
              type: CardType.audio,
              answer: note.isEmpty ? null : note,
              mediaPath: stored.mediaPath,
              mediaDurationMs:
                  (_actualDuration ?? widget.duration).inMilliseconds,
            ),
          );

      ref.invalidate(reviewQueueProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: ViewfinderColors.deep,
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ViewfinderColors.surface),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.md,
                    AppSpacing.xxl,
                    0,
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: ViewfinderColors.text,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Waveform(levels: widget.levels, height: 72),
                        const SizedBox(height: AppSpacing.xxl),
                        AudioPlayerBar(
                          path: widget.clip.path,
                          onViewfinder: true,
                          onDuration: (d) => _actualDuration = d,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPadding(
                duration: AppDuration.fast,
                padding: EdgeInsets.only(bottom: keyboard),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  decoration: const BoxDecoration(
                    color: ViewfinderColors.sheet,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xxl),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OptionalFieldRow(
                        label: l10n.addNote,
                        optionalLabel: l10n.optional,
                        expanded: _noteExpanded,
                        onViewfinder: true,
                        onTap: () {
                          setState(() => _noteExpanded = !_noteExpanded);
                          if (_noteExpanded) _noteFocus.requestFocus();
                        },
                      ),
                      if (_noteExpanded) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _noteController,
                          focusNode: _noteFocus,
                          maxLines: 2,
                          minLines: 2,
                          cursorColor: AppPalette.accent,
                          style: AppText.body(
                            size: 15,
                            color: ViewfinderColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.noteHint,
                            hintStyle: AppText.body(
                              size: 15,
                              color: ViewfinderColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: ViewfinderColors.fill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AccentButton(
                        label: l10n.save,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
