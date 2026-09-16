import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/local/prefs_settings_repository.dart';
import '../../core/widgets/video_player_view.dart' show formatClipDuration;
import '../../l10n/app_localizations.dart';
import 'photo_confirm_screen.dart';
import 'video_confirm_screen.dart';

/// Camera mode -- a full-screen viewfinder.
///
/// ## The permission flow is contextual
/// Permission is not requested when the user **swipes** into Camera mode:
/// swiping is navigation, not a declaration of intent. It is asked for on the
/// first **shutter tap** -- the moment the user knows exactly what it is for.
///
/// That has a cost: the `camera` plugin cannot report permission status without
/// asking for it. So a granted permission is remembered in the
/// `settings.cameraGranted` flag and the viewfinder starts directly on later
/// launches -- otherwise the camera would have to be woken by hand every time.
///
/// ## Tap = photo, press and hold = video
/// The viewfinder opens with a **silent** controller (`enableAudio: false`):
/// a user who only takes photos is never asked for microphone permission. Once
/// the press-and-hold threshold is crossed, the controller is swapped for the
/// audio-enabled one and recording starts then -- microphone permission is
/// requested at that exact moment. The cost is
/// that recording begins a few hundred milliseconds after the finger lands. The
/// red ring appears only while actually recording, so we are not lying about it.
class CameraPanel extends ConsumerStatefulWidget {
  const CameraPanel({super.key, required this.isActive});

  /// Whether Camera mode is the visible page right now. `PageView` builds all
  /// four panels; without this the camera would stay open behind the user while
  /// they type -- a battery and a privacy matter.
  final bool isActive;

  @override
  ConsumerState<CameraPanel> createState() => _CameraPanelState();
}

enum _CameraStage { idle, starting, live, denied }

class _CameraPanelState extends ConsumerState<CameraPanel>
    with WidgetsBindingObserver {
  /// A press longer than this means video.
  static const Duration _holdThreshold = Duration(milliseconds: 320);

  CameraController? _controller;
  _CameraStage _stage = _CameraStage.idle;
  FlashMode _flash = FlashMode.off;
  bool _capturing = false;

  Timer? _holdTimer;
  Timer? _recordTicker;
  bool _recording = false;
  bool _pointerDown = false;
  Duration _recorded = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive && _rememberedPermission) _start();
  }

  @override
  void didUpdateWidget(CameraPanel old) {
    super.didUpdateWidget(old);
    if (widget.isActive == old.isActive) return;
    // The camera is released on leaving the mode: one left open burns battery
    // and makes the user wonder whether it is watching them.
    if (widget.isActive) {
      if (_rememberedPermission) _start();
    } else {
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _rememberedPermission) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _recordTicker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  bool get _rememberedPermission =>
      ref.read(settingsRepositoryProvider).cameraGranted;

  /// Opens the camera. Without permission the system dialog appears **here**.
  ///
  /// [withAudio] is `true` only for video recording: an audio-enabled controller
  /// triggers microphone permission, which taking a photo does not need.
  Future<void> _start({bool withAudio = false}) async {
    if (_stage == _CameraStage.starting) return;
    if (_stage == _CameraStage.live && !withAudio) return;
    setState(() => _stage = _CameraStage.starting);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        // A device with no camera: the manifest says `required="false"`, so the
        // app installs on one anyway.
        if (mounted) setState(() => _stage = _CameraStage.denied);
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        // Silent viewfinder: microphone permission only for video recording.
        enableAudio: withAudio,
      );
      await controller.initialize();
      await controller.setFlashMode(_flash);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // The new one was created before releasing the old (so the camera never
      // sits idle); now the old one can go.
      final previous = _controller;
      await ref.read(settingsRepositoryProvider).setCameraGranted(true);
      setState(() {
        _controller = controller;
        _stage = _CameraStage.live;
      });
      await previous?.dispose();
    } on CameraException catch (e) {
      debugPrint('Could not open the camera: ${e.code} ${e.description}');
      // Permission may have been revoked; the remembered flag is now lying.
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted') {
        await ref.read(settingsRepositoryProvider).setCameraGranted(false);
      }
      if (mounted) setState(() => _stage = _CameraStage.denied);
    }
  }

  Future<void> _stop() async {
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() => _stage = _CameraStage.idle);
    await controller?.dispose();
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } on CameraException catch (e) {
      // A camera without a flash rejects the setting; it must not block capture.
      debugPrint('Could not set the flash: ${e.code}');
    }
  }

  /// The finger touched the shutter: video if the threshold fills, photo if it lifts first.
  void _onShutterDown() {
    _pointerDown = true;
    if (_stage != _CameraStage.live) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdThreshold, _startVideo);
  }

  Future<void> _onShutterUp() async {
    _pointerDown = false;
    final wasWaiting = _holdTimer?.isActive ?? false;
    _holdTimer?.cancel();
    _holdTimer = null;

    if (_recording) {
      await _stopVideo();
      return;
    }
    // The threshold did not fill, so this was a tap.
    if (wasWaiting || _stage != _CameraStage.live) await _onShutter();
  }

  Future<void> _onShutter() async {
    // If permission has not been asked for yet, the shutter's first job is to wake the camera.
    if (_stage != _CameraStage.live) {
      await _start();
      return;
    }

    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.lightImpact();

    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      await PhotoConfirmScreen.open(context, File(shot.path));
    } on CameraException catch (e) {
      debugPrint('Could not take the photo: ${e.code} ${e.description}');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Swaps to the audio controller and starts recording. Microphone permission is asked for here.
  Future<void> _startVideo() async {
    if (_recording || _capturing) return;

    await _start(withAudio: true);
    final controller = _controller;
    if (controller == null || !mounted) return;

    try {
      await controller.startVideoRecording();
    } on CameraException catch (e) {
      debugPrint('Video recording did not start: ${e.code} ${e.description}');
      // If the audio controller could not be created (microphone refused), fall
      // back to silent; the viewfinder has to keep working.
      await _start();
      return;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _recording = true;
      _recorded = Duration.zero;
    });
    _recordTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() => _recorded += const Duration(milliseconds: 200));
      }
    });

    // If recording started after the finger lifted (the permission dialog got in
    // the way), stop immediately: the user did not ask for a video.
    if (_holdTimer == null && !_pointerDown) await _stopVideo();
  }

  Future<void> _stopVideo() async {
    if (!_recording) return;
    _recordTicker?.cancel();
    final controller = _controller;
    setState(() => _recording = false);

    XFile? clip;
    try {
      clip = await controller?.stopVideoRecording();
    } on CameraException catch (e) {
      debugPrint('Could not stop the video: ${e.code} ${e.description}');
    }

    HapticFeedback.lightImpact();
    // The viewfinder returns to the silent controller: recording is over and
    // there is no reason to keep holding the microphone.
    await _start();

    if (clip != null && mounted) {
      await VideoConfirmScreen.open(context, File(clip.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_stage == _CameraStage.live && _controller != null)
          _Preview(controller: _controller!),
        if (_stage == _CameraStage.denied)
          _DeniedState(onAllow: _start)
        else
          _ShutterArea(
            onPressStart: _onShutterDown,
            onPressEnd: _onShutterUp,
            busy: _capturing,
            recording: _recording,
            elapsed: _recorded,
          ),
        // The flash button is hidden while recording: changing flash mode
        // mid-recording does nothing, and a second control beside the red ring
        // is a distraction.
        if (_stage == _CameraStage.live && !_recording)
          _FlashButton(mode: _flash, onTap: _cycleFlash),
      ],
    );
  }
}

/// The viewfinder **fills the screen**: because the preview's aspect ratio does
/// not match the screen's, whatever overflows the edges is cropped. The
/// alternative -- fitting it -- would leave black bars above and below, which
/// a full-screen viewfinder rules out.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          // `aspectRatio` arrives landscape-referenced; a portrait viewfinder
          // needs the inverse.
          height: size.width * controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// The shutter: a 78dp outer ring, a 4dp white edge, a 62dp inner circle.
/// While recording the ring turns red and the inner circle shrinks into a
/// rounded square.
class _ShutterArea extends StatelessWidget {
  const _ShutterArea({
    required this.onPressStart,
    required this.onPressEnd,
    required this.busy,
    required this.recording,
    required this.elapsed,
  });

  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final bool busy;
  final bool recording;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // Leaves room below the shutter for the islet.
        padding: const EdgeInsets.only(bottom: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The recording badge appears only while recording; an empty
            // counter should not sit on the screen.
            if (recording) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ViewfinderColors.record.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '● ${formatClipDuration(elapsed)}',
                  style: AppText.body(
                    size: 13,
                    weight: 600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Listener(
              onPointerDown: (_) => busy ? null : onPressStart(),
              onPointerUp: (_) => onPressEnd(),
              onPointerCancel: (_) => onPressEnd(),
              child: AnimatedOpacity(
                opacity: busy ? 0.6 : 1,
                duration: AppDuration.fast,
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: recording
                          ? ViewfinderColors.record
                          : Colors.white,
                      width: 4,
                    ),
                    boxShadow: recording
                        ? [
                            BoxShadow(
                              color: ViewfinderColors.record
                                  .withValues(alpha: 0.35),
                              spreadRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    width: recording ? 32 : 62,
                    height: recording ? 32 : 62,
                    decoration: BoxDecoration(
                      color:
                          recording ? ViewfinderColors.record : Colors.white,
                      borderRadius: BorderRadius.circular(
                        recording ? AppRadius.sm : AppRadius.pill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flash: top right corner, an icon, no text.
class _FlashButton extends StatelessWidget {
  const _FlashButton({required this.mode, required this.onTap});

  final FlashMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: AppSpacing.xxl,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x2EFFFFFF),
            ),
            child: Text(
              switch (mode) {
                FlashMode.always => '⚡',
                FlashMode.auto => 'A',
                _ => '🚫',
              },
              style: AppText.body(
                size: mode == FlashMode.auto ? 13 : 12,
                weight: 700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The in-screen state that replaces the viewfinder when permission is refused.
///
/// After one refusal the system dialog never appears again; without this screen
/// the user would keep tapping a shutter that does nothing.
class _DeniedState extends StatelessWidget {
  const _DeniedState({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📷', style: TextStyle(fontSize: 34)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.permCameraDenied,
              textAlign: TextAlign.center,
              style: AppText.body(
                size: 14,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            InkWell(
              onTap: onAllow,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.accent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  l10n.permAllow,
                  style: AppText.body(
                    size: 15,
                    weight: 600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
