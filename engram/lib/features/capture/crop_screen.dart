import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/accent_button.dart';
import '../../l10n/app_localizations.dart';

/// The image crop screen.
///
/// **The default selection is the whole frame.** Cropping is not compulsory:
/// the user can press Continue without touching anything and keep the photo
/// exactly as it is. Opening with an empty selection would impose a chore on
/// every single photo.
///
/// The screen is always on a dark surface. The same screen opens on the white
/// paper surface for a PDF page -- that is [paperSurface].
class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.source,
    this.paperSurface = false,
  });

  final File source;

  /// A PDF page is always cropped on a white ground.
  final bool paperSurface;

  /// Returns the **new** cropped file, or `null` if the user backs out.
  /// If the selection never changed, the source file itself is returned -- a
  /// needless re-encode would degrade the image for no reason.
  static Future<File?> open(
    BuildContext context,
    File source, {
    bool paperSurface = false,
  }) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CropScreen(source: source, paperSurface: paperSurface),
      ),
    );
  }

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  /// The selection is kept in the 0..1 range, **relative to the image's
  /// rectangle on screen**. Stored as pixel coordinates it would shift when the
  /// screen rotated or the layout changed; a ratio means the same place at any scale.
  Rect _selection = const Rect.fromLTRB(0, 0, 1, 1);

  Size? _imageSize;
  bool _working = false;

  /// Whether the touch grabbed a corner or is moving the selection.
  _Grab? _grab;

  @override
  void initState() {
    super.initState();
    _readImageSize();
  }

  /// The image's real aspect ratio is needed: the on-screen rectangle is
  /// computed from it, and the selection stays inside that rectangle.
  Future<void> _readImageSize() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final decoded = await ui.instantiateImageCodec(bytes);
      final frame = await decoded.getNextFrame();
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
      frame.image.dispose();
    } catch (e) {
      debugPrint('Could not read the image: $e');
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// The rectangle the image occupies on screen (`BoxFit.contain`).
  Rect _imageRect(Size available) {
    final size = _imageSize;
    if (size == null) return Offset.zero & available;

    final scale = (available.width / size.width)
        .clamp(0.0, available.height / size.height);
    final w = size.width * scale;
    final h = size.height * scale;
    return Rect.fromLTWH(
      (available.width - w) / 2,
      (available.height - h) / 2,
      w,
      h,
    );
  }

  Rect _selectionInPixels(Rect imageRect) => Rect.fromLTRB(
        imageRect.left + _selection.left * imageRect.width,
        imageRect.top + _selection.top * imageRect.height,
        imageRect.left + _selection.right * imageRect.width,
        imageRect.top + _selection.bottom * imageRect.height,
      );

  void _onPanStart(Offset local, Rect imageRect) {
    final sel = _selectionInPixels(imageRect);
    const grabRadius = 44.0;

    final corners = {
      _Grab.topLeft: sel.topLeft,
      _Grab.topRight: sel.topRight,
      _Grab.bottomLeft: sel.bottomLeft,
      _Grab.bottomRight: sel.bottomRight,
    };

    for (final entry in corners.entries) {
      if ((local - entry.value).distance <= grabRadius) {
        _grab = entry.key;
        return;
      }
    }

    // If no corner was grabbed: a drag starting inside the selection moves it,
    // one starting outside draws a new selection (drag-select).
    //
    // **While the whole image is selected, a drag always draws.** With the
    // full frame selected there is no "outside", and moving a selection
    // already pinned to the edges would do nothing -- so drag-select would
    // never work.
    if (sel.contains(local) && !isWholeSelection(_selection)) {
      _grab = _Grab.move;
    } else {
      _grab = _Grab.draw;
      final n = _normalize(local, imageRect);
      setState(() => _selection = Rect.fromPoints(n, n));
    }
  }

  Offset _normalize(Offset local, Rect imageRect) => Offset(
        ((local.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
        ((local.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
      );

  void _onPanUpdate(Offset local, Offset delta, Rect imageRect) {
    final n = _normalize(local, imageRect);
    final dx = delta.dx / imageRect.width;
    final dy = delta.dy / imageRect.height;

    setState(() {
      switch (_grab) {
        case _Grab.move:
          // The selection must not shrink while moving: it stops at the edge.
          final w = _selection.width;
          final h = _selection.height;
          final left = (_selection.left + dx).clamp(0.0, 1 - w);
          final top = (_selection.top + dy).clamp(0.0, 1 - h);
          _selection = Rect.fromLTWH(left, top, w, h);
        case _Grab.draw:
          _selection = Rect.fromPoints(_selection.topLeft, n);
        case _Grab.topLeft:
          _selection = Rect.fromLTRB(
              n.dx, n.dy, _selection.right, _selection.bottom);
        case _Grab.topRight:
          _selection =
              Rect.fromLTRB(_selection.left, n.dy, n.dx, _selection.bottom);
        case _Grab.bottomLeft:
          _selection =
              Rect.fromLTRB(n.dx, _selection.top, _selection.right, n.dy);
        case _Grab.bottomRight:
          _selection =
              Rect.fromLTRB(_selection.left, _selection.top, n.dx, n.dy);
        case null:
          break;
      }
    });
  }

  void _onPanEnd(Rect imageRect) {
    _grab = null;
    // Fix an inverted rectangle (dragged right to left) and pull a too-small
    // selection up to a usable size.
    final minSide = 48 / imageRect.shortestSide;
    var r = Rect.fromLTRB(
      _selection.left < _selection.right ? _selection.left : _selection.right,
      _selection.top < _selection.bottom ? _selection.top : _selection.bottom,
      _selection.left < _selection.right ? _selection.right : _selection.left,
      _selection.top < _selection.bottom ? _selection.bottom : _selection.top,
    );
    if (r.width < minSide || r.height < minSide) {
      r = Rect.fromLTWH(
        r.left.clamp(0.0, 1 - minSide),
        r.top.clamp(0.0, 1 - minSide),
        minSide,
        minSide,
      );
    }
    setState(() => _selection = r);
  }

  bool get _isWholeImage => isWholeSelection(_selection);

  Future<void> _continue() async {
    if (_working) return;

    // If nothing was cropped we leave the file alone: re-encoding degrades the
    // image for no reason and copies a file that was already in place.
    if (_isWholeImage) {
      Navigator.of(context).pop(widget.source);
      return;
    }

    setState(() => _working = true);
    try {
      // Cropping in an isolate: decoding and re-encoding a 12MP photo on the
      // UI thread means seconds of freeze.
      final cropped = await compute(
        _cropInIsolate,
        _CropRequest(
          path: widget.source.path,
          left: _selection.left,
          top: _selection.top,
          right: _selection.right,
          bottom: _selection.bottom,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(cropped == null ? null : File(cropped));
    } catch (e) {
      debugPrint('Crop failed: $e');
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final onPaper = widget.paperSurface;
    final foreground = onPaper ? PaperColors.text : ViewfinderColors.text;

    return Scaffold(
      backgroundColor: onPaper ? PaperColors.surface : ViewfinderColors.deep,
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
                    color: foreground,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.cropSelectArea,
                    style: AppText.voice(size: 17, color: foreground),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  final imageRect = _imageRect(available);

                  return GestureDetector(
                    onPanStart: (d) => _onPanStart(d.localPosition, imageRect),
                    onPanUpdate: (d) => _onPanUpdate(
                      d.localPosition,
                      d.delta,
                      imageRect,
                    ),
                    onPanEnd: (_) => _onPanEnd(imageRect),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fromRect(
                          rect: imageRect,
                          child: Image.file(widget.source, fit: BoxFit.fill),
                        ),
                        if (_imageSize != null)
                          CustomPaint(
                            painter: _MarqueePainter(
                              selection: _selectionInPixels(imageRect),
                              imageRect: imageRect,
                              // A white line is invisible on white paper: on
                              // the PDF screen the crop frame would vanish
                              // completely. The line colour has to be bound
                              // to the surface.
                              //
                              // On paper, **accent** rather than black: a
                              // black frame blends into the page's own text,
                              // while the brand colour says "you are drawing
                              // this". Over the viewfinder it stays white --
                              // what is underneath is unknown, and white reads.
                              line: onPaper
                                  ? AppPalette.accent
                                  : Colors.white,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.cropHintArea,
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      size: 13,
                      color: onPaper
                          ? PaperColors.text.withValues(alpha: 0.55)
                          : ViewfinderColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AccentButton(
                    label: l10n.cropContinue,
                    onPressed: _working ? null : _continue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Grab { move, draw, topLeft, topRight, bottomLeft, bottomRight }

/// Is the selection effectively the whole image?
///
/// Exact equality is not required: dragging is floating point and "sticking" to
/// an edge produces values like 0.9997. Re-encoding a 12MP photo over a
/// thousandth of a pixel makes no sense.
bool isWholeSelection(Rect selection) =>
    selection.left <= 0.001 &&
    selection.top <= 0.001 &&
    selection.right >= 0.999 &&
    selection.bottom >= 0.999;

/// Converts a proportional selection into a pixel rectangle.
///
/// The bounds are clamped: a rectangle that rounding pushes one pixel outside
/// the image would blow up `copyCrop`.
({int x, int y, int width, int height}) cropRectInPixels(
  Rect selection,
  int imageWidth,
  int imageHeight,
) {
  final x = (selection.left * imageWidth).round().clamp(0, imageWidth - 1);
  final y = (selection.top * imageHeight).round().clamp(0, imageHeight - 1);
  final width =
      (selection.width * imageWidth).round().clamp(1, imageWidth - x);
  final height =
      (selection.height * imageHeight).round().clamp(1, imageHeight - y);
  return (x: x, y: y, width: width, height: height);
}

/// Darkens outside the selection and draws the border and four corner handles.
class _MarqueePainter extends CustomPainter {
  const _MarqueePainter({
    required this.selection,
    required this.imageRect,
    required this.line,
  });

  final Rect selection;
  final Rect imageRect;

  /// The frame and handle colour -- it follows the surface (a white line is
  /// invisible on white paper).
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    // Darkening only over the image: the margins at the edges are already ground.
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(imageRect),
      Path()..addRect(selection),
    );
    canvas.drawPath(shade, Paint()..color = const Color(0x8C000000));

    canvas.drawRect(
      selection,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = line,
    );

    // Corner handles: thick L-shaped strokes. Filled squares covered the corner
    // of the image itself.
    const arm = 22.0;
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..color = line;

    void corner(Offset at, double dx, double dy) {
      canvas.drawLine(at, at.translate(arm * dx, 0), handle);
      canvas.drawLine(at, at.translate(0, arm * dy), handle);
    }

    corner(selection.topLeft, 1, 1);
    corner(selection.topRight, -1, 1);
    corner(selection.bottomLeft, 1, -1);
    corner(selection.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_MarqueePainter old) =>
      old.selection != selection ||
      old.imageRect != imageRect ||
      old.line != line;
}

/// A plain carrier so it can cross the [compute] boundary -- `Rect` and `File`
/// cannot be sent.
class _CropRequest {
  const _CropRequest({
    required this.path,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String path;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Runs in a background isolate. Returns the path of the new file.
String? _cropInIsolate(_CropRequest req) {
  final bytes = File(req.path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final rect = cropRectInPixels(
    Rect.fromLTRB(req.left, req.top, req.right, req.bottom),
    decoded.width,
    decoded.height,
  );

  final cropped = img.copyCrop(
    decoded,
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
  );

  // Written beside the source; moving it to the permanent folder is [MediaStore]'s job.
  final target = p.join(
    p.dirname(req.path),
    '${p.basenameWithoutExtension(req.path)}_crop.jpg',
  );
  File(target).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
  return target;
}
