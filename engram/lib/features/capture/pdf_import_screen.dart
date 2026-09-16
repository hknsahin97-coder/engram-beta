import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../data/models/memory_card.dart';
import '../../l10n/app_localizations.dart';
import 'crop_screen.dart';
import 'photo_confirm_screen.dart';

/// Making a card from a PDF.
///
/// The flow: pick a file -> see the page (browse with the arrows) -> Continue
/// -> crop -> confirm. The page is **rendered to an image**; the card is bound
/// to that page's image, not to a PDF. The reason: what the card reminds you of
/// has to stay put even if the user deletes or moves the source.
///
/// ## Surface
/// This screen is **always white**, dark theme included. Showing a
/// page on a dark ground makes it look like part of the screen; paper has to
/// look like paper.
///
/// ## Changing page resets the selection
/// This holds by itself: cropping is a separate
/// screen and opens fresh for each page. Carrying a selection between pages
/// would be meaningless anyway -- the same rectangle working on two pages
/// would be a coincidence.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key, required this.file});

  final File file;

  /// Prompts for a file and opens the screen if one is chosen. Returns quietly
  /// if the user cancels -- cancelling is not an error.
  static Future<void> pick(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PdfImportScreen(file: File(path)),
      ),
    );
  }

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  PdfDocument? _document;
  int _pageNumber = 1;
  File? _rendered;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() => _document = doc);
      await _renderPage(1);
    } catch (e) {
      debugPrint('Could not open the PDF: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = L10n.of(context).pdfOpenFailed;
        });
      }
    }
  }

  Future<void> _renderPage(int number) async {
    final doc = _document;
    if (doc == null) return;
    setState(() => _busy = true);

    PdfPage? page;
    try {
      page = await doc.getPage(number);
      // 2x: the page has to stay readable after cropping too. Rendered at the
      // page's own size, a small excerpt comes out blurry.
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      if (image == null) throw StateError('render returned nothing');

      final tmp = await getTemporaryDirectory();
      final target = File(
        p.join(tmp.path, 'pdf_page_${number}_'
            '${DateTime.now().microsecondsSinceEpoch}.png'),
      );
      await target.writeAsBytes(image.bytes);

      if (!mounted) return;
      setState(() {
        _rendered = target;
        _pageNumber = number;
        _busy = false;
      });
    } catch (e) {
      debugPrint('Could not render the PDF page: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = L10n.of(context).pdfOpenFailed;
        });
      }
    } finally {
      await page?.close();
    }
  }

  Future<void> _continue() async {
    final rendered = _rendered;
    if (rendered == null || _busy) return;

    final cropped = await CropScreen.open(context, rendered, paperSurface: true);
    if (cropped == null || !mounted) return;

    await PhotoConfirmScreen.open(
      context,
      cropped,
      cardType: CardType.pdfSnippet,
      // E.g. "biology-notes.pdf · page 3" -- the one line that says where the
      // card came from. If the user wants to go back to the source, this is
      // the only clue they have.
      sourceLabel: '${p.basename(widget.file.path)} · page $_pageNumber',
      paperSurface: true,
    );

    // There is no coming back here after confirmation: the card exists, done.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pageCount = _document?.pagesCount ?? 1;

    return Scaffold(
      // Paper surface: independent of the theme, always white.
      backgroundColor: PaperColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: PaperColors.text,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      p.basename(widget.file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.voice(size: 17, color: PaperColors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: switch ((_error, _rendered)) {
                  (final String message, _) => Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 14,
                        color: PaperColors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  (_, final File file) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Image.file(
                        file,
                        key: ValueKey(file.path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
            if (_error == null) ...[
              // Page navigation only for a multi-page document: two dead
              // arrows on a one-page PDF make no sense.
              if (pageCount > 1)
                _PageNav(
                  page: _pageNumber,
                  count: pageCount,
                  busy: _busy,
                  onPrevious:
                      _pageNumber > 1 ? () => _renderPage(_pageNumber - 1) : null,
                  onNext: _pageNumber < pageCount
                      ? () => _renderPage(_pageNumber + 1)
                      : null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.md,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: AccentButton(
                  label: l10n.cropContinue,
                  onPressed: _busy || _rendered == null ? null : _continue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.page,
    required this.count,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int count;
  final bool busy;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    Widget arrow(String glyph, VoidCallback? onTap) => InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Text(
              glyph,
              style: AppText.body(
                size: 20,
                weight: 600,
                color: PaperColors.text.withValues(
                  alpha: onTap == null ? 0.2 : 0.7,
                ),
              ),
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        arrow('‹', onPrevious),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            L10n.of(context).pdfPageOf(page, count),
            style: AppText.body(
              size: 13,
              weight: 500,
              color: PaperColors.text.withValues(alpha: 0.6),
            ),
          ),
        ),
        arrow('›', onNext),
      ],
    );
  }
}
