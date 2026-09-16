import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/media/media_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/optional_field_row.dart';
import '../../core/widgets/video_player_view.dart';
import '../../data/models/memory_card.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';

/// The confirmation screen for a recorded video.
///
/// The same skeleton as photo and audio: preview, optional note, Save. The
/// preview can be played -- nobody should have to create a card without seeing
/// what they just recorded.
class VideoConfirmScreen extends ConsumerStatefulWidget {
  const VideoConfirmScreen({super.key, required this.clip});

  final File clip;

  static Future<void> open(BuildContext context, File clip) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VideoConfirmScreen(clip: clip),
        ),
      );

  @override
  ConsumerState<VideoConfirmScreen> createState() =>
      _VideoConfirmScreenState();
}

class _VideoConfirmScreenState extends ConsumerState<VideoConfirmScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  bool _noteExpanded = false;
  bool _saving = false;
  Duration? _duration;

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
            idHint: 'video',
            extension: _extensionFor(widget.clip.path),
            // No thumbnail is generated from a video: extracting a frame would
            // need a native plugin. The poster is the
            // first frame the player shows.
            makeThumbnail: false,
          );

      final note = _noteController.text.trim();
      await ref.read(cardRepositoryProvider).add(
            MemoryCard.create(
              type: CardType.video,
              answer: note.isEmpty ? null : note,
              mediaPath: stored.mediaPath,
              mediaDurationMs: _duration?.inMilliseconds,
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

  /// On Android the file the camera leaves behind has a `.temp` extension: the
  /// plugin writes the recording to a temporary name. Stored as-is, the file in
  /// the library becomes `video_….temp` and the exported backup is recognised
  /// by no other tool. A file coming from the gallery already has the right
  /// extension -- that one is left alone.
  static String _extensionFor(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return (ext.isEmpty || ext == 'temp') ? 'mp4' : ext;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: ViewfinderColors.deep,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: VideoPlayerView(
                    path: widget.clip.path,
                    onDuration: (d) => _duration = d,
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
                            borderRadius: BorderRadius.circular(AppRadius.lg),
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
    );
  }
}
