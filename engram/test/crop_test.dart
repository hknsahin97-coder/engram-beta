import 'package:engram/features/capture/crop_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('crop selection', () {
    test('the default selection counts as the whole image', () {
      // Cropping is not compulsory: the user has to be able to press Continue
      // without touching anything and keep the photo as it is.
      expect(isWholeSelection(const Rect.fromLTRB(0, 0, 1, 1)), isTrue);
    });

    test('a drag that sticks to the edge also counts as the whole image', () {
      // Dragging is floating point; re-encoding a 12MP photo over 0.9997
      // degrades the image for no reason.
      expect(
        isWholeSelection(const Rect.fromLTRB(0.0004, 0, 0.9997, 0.9995)),
        isTrue,
      );
    });

    test('a real crop does not count as the whole image', () {
      expect(isWholeSelection(const Rect.fromLTRB(0.1, 0, 1, 1)), isFalse);
      expect(isWholeSelection(const Rect.fromLTRB(0, 0, 1, 0.8)), isFalse);
    });
  });

  group('pixel conversion', () {
    test('a ratio converts correctly into pixels', () {
      final r = cropRectInPixels(
        const Rect.fromLTRB(0.25, 0.5, 0.75, 1.0),
        400,
        200,
      );
      expect(r, (x: 100, y: 100, width: 200, height: 100));
    });

    test('a full selection gives the whole image', () {
      final r = cropRectInPixels(const Rect.fromLTRB(0, 0, 1, 1), 300, 500);
      expect(r, (x: 0, y: 0, width: 300, height: 500));
    });

    test('an overflowing selection is clamped to the bounds', () {
      // A rectangle that rounding pushes one pixel outside blows up `copyCrop`
      // at run time -- it is cut back here.
      final r = cropRectInPixels(
        const Rect.fromLTRB(0.9, 0.9, 1.4, 1.4),
        100,
        100,
      );
      expect(r.x + r.width, lessThanOrEqualTo(100));
      expect(r.y + r.height, lessThanOrEqualTo(100));
    });

    test('a zero-area selection is at least one pixel', () {
      final r = cropRectInPixels(
        const Rect.fromLTRB(0.5, 0.5, 0.5, 0.5),
        100,
        100,
      );
      expect(r.width, greaterThanOrEqualTo(1));
      expect(r.height, greaterThanOrEqualTo(1));
    });
  });
}
