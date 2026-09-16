import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture_mode.dart';

/// The key attached to the Library icon in the top left.
///
/// The save animation needs it to know where to fly: the target's real
/// position on screen is read from here rather than assuming a fixed
/// coordinate (safe areas and screen sizes differ by device).
final libraryIconKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

/// Two equal primary screens. There is **no swipe** between them -- the
/// transition happens only through the floating islet. A
/// swipe would collide with the horizontal mode swiper inside `Add`.
enum ShellPage { add, review }

final shellPageProvider = NotifierProvider<ShellPageController, ShellPage>(
  ShellPageController.new,
);

class ShellPageController extends Notifier<ShellPage> {
  @override
  ShellPage build() => ShellPage.add;

  void go(ShellPage page) => state = page;
}

final captureModeProvider = NotifierProvider<CaptureModeController, CaptureMode>(
  CaptureModeController.new,
);

class CaptureModeController extends Notifier<CaptureMode> {
  /// The app opens in Camera mode.
  @override
  CaptureMode build() => CaptureMode.camera;

  void select(CaptureMode mode) => state = mode;
}
