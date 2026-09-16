/// The four capture modes on the `Add` screen.
///
/// The order is Camera, Text, Import, Audio -- the page order of the
/// horizontal swiper and of the chip row.
enum CaptureMode { camera, text, import, audio }

extension CaptureModeSurface on CaptureMode {
  /// Does this mode use the viewfinder surface?
  ///
  /// Camera, Import and Audio always run on the **dark** viewfinder surface,
  /// even when the user is in the light theme. Only Text mode sits on the
  /// theme surface.
  bool get usesViewfinder => this != CaptureMode.text;

  int get pageIndex => index;
}
