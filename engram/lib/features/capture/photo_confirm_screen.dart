import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../core/widgets/optional_field_row.dart';
import '../../data/models/memory_card.dart';
import '../../data/repositories/isar_card_repository.dart';
import '../../domain/srs/review_queue_provider.dart';
import '../../l10n/app_localizations.dart';
import 'crop_screen.dart';

/// The confirmation screen for a captured photo.
///
/// The card is created here, not at the shutter: a shot often does not work
/// first time, and the user may want to add a note. Leaving with the close
/// button goes back without ever creating a card.
///
/// The scissors leads to the crop screen and returns here with the
/// cropped image.
class PhotoConfirmScreen extends ConsumerStatefulWidget {
  const PhotoConfirmScreen({
    super.key,
    required this.photo,
    this.cardType = CardType.photo,
    this.sourceLabel,
    this.paperSurface = false,
  });

  /// The **temporary** file handed over by the camera or the gallery. If saved,
  /// [MediaStore] copies it into the permanent folder; if not, the OS deletes it
  /// sooner or later.
  final File photo;

  /// One screen serves three sources: camera, gallery and PDF page. The source
  /// only changes the card's type; the confirmation flow is the same.
  final CardType cardType;

  /// E.g. `biology-notes.pdf · page 3`. Only set on PDF excerpts.
  final String? sourceLabel;

  /// A PDF page is always confirmed on the white paper surface.
  final bool paperSurface;

  static Future<void> open(
    BuildContext context,
    File photo, {
    CardType cardType = CardType.photo,
    String? sourceLabel,
    bool paperSurface = false,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PhotoConfirmScreen(
            photo: photo,
            cardType: cardType,
            sourceLabel: sourceLabel,
            paperSurface: paperSurface,
          ),
        ),
      );

  @override
  ConsumerState<PhotoConfirmScreen> createState() => _PhotoConfirmScreenState();
}

class _PhotoConfirmScreenState extends ConsumerState<PhotoConfirmScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  bool _noteExpanded = false;
  bool _saving = false;

  /// This is what gets saved if it was cropped. The source file is untouched:
  /// the user has to be able to press the scissors again and choose a wider
  /// area, so one crop never stacks on another.
  File? _cropped;

  File get _current => _cropped ?? widget.photo;

  Future<void> _crop() async {
    final result = await CropScreen.open(
      context,
      widget.photo,
      paperSurface: widget.paperSurface,
    );
    if (result != null && mounted) setState(() => _cropped = result);
  }

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
            source: _current,
            idHint: 'photo',
            // The Library grid should not load the full-size photo: twenty
            // cards in a two-column grid would mean twenty full-resolution images.
            makeThumbnail: true,
          );

      final note = _noteController.text.trim();
      await ref.read(cardRepositoryProvider).add(
            MemoryCard.create(
              type: widget.cardType,
              // A media card has no question: the face of the card is the image
              // itself. A note goes into the answer field (one field for both).
              answer: note.isEmpty ? null : note,
              mediaPath: stored.mediaPath,
              thumbnailPath: stored.thumbnailPath,
              sourceLabel: widget.sourceLabel,
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

    return Scaffold(
      // The confirmation screen is **theme-independent**: a photo is confirmed
      // on the dark viewfinder surface, a PDF page on the white paper one.
      backgroundColor:
          widget.paperSurface ? PaperColors.surface : ViewfinderColors.deep,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _current,
            // A PDF page must not be cropped by the layout: a page with its
            // edges cut reads wrongly. For a photo, filling the screen is right.
            fit: widget.paperSurface ? BoxFit.contain : BoxFit.cover,
            // Had the crop been written to the same path, Flutter would show
            // the old frame from cache; the file name changes so it is fine,
            // but the key is still bound to the file.
            key: ValueKey(_current.path),
          ),
          Positioned(
            top: AppSpacing.xxl,
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconButton(
                    glyph: '✕',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _IconButton(glyph: '✂️', onTap: _crop),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ConfirmSheet(
              noteController: _noteController,
              noteFocus: _noteFocus,
              expanded: _noteExpanded,
              saving: _saving,
              onToggleNote: () {
                setState(() => _noteExpanded = !_noteExpanded);
                if (_noteExpanded) _noteFocus.requestFocus();
              },
              onSave: _save,
              l10n: l10n,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.noteController,
    required this.noteFocus,
    required this.expanded,
    required this.saving,
    required this.onToggleNote,
    required this.onSave,
    required this.l10n,
  });

  final TextEditingController noteController;
  final FocusNode noteFocus;
  final bool expanded;
  final bool saving;
  final VoidCallback onToggleNote;
  final VoidCallback onSave;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
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
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OptionalFieldRow(
                label: l10n.addNote,
                optionalLabel: l10n.optional,
                expanded: expanded,
                onTap: onToggleNote,
                onViewfinder: true,
              ),
              if (expanded) ...[
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: noteController,
                  focusNode: noteFocus,
                  maxLines: 2,
                  minLines: 2,
                  cursorColor: AppPalette.accent,
                  style: AppText.body(size: 15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: l10n.noteHint,
                    hintStyle: AppText.body(
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: const Color(0x14FFFFFF),
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
                onPressed: saving ? null : onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.glyph, required this.onTap});

  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x59000000),
        ),
        child: Text(
          glyph,
          style: AppText.body(size: 15, weight: 600, color: Colors.white),
        ),
      ),
    );
  }
}
