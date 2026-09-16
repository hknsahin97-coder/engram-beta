import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../media/media_clip.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The face of a video card: **first frame plus play**.
///
/// No separate poster file is produced; that would need a frame-extraction
/// plugin such as `video_thumbnail`. `video_player` already shows the first
/// frame once initialised -- that is the poster.
///
/// **It does not autoplay.** The review screen may have been opened in a quiet
/// room; sound is the user's decision.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.path,
    this.maxHeight,
    this.onDuration,
    this.mediaStartMs,
    this.mediaEndMs,
    this.controllerFactory,
    this.videoBuilder,
  });

  /// An **absolute** path.
  final String path;

  final double? maxHeight;

  /// Reports the real duration once the file is opened (used when saving).
  final ValueChanged<Duration>? onDuration;

  /// Trim bounds measured from the start of the file. Both being `null` keeps
  /// older cards playing the whole file.
  final int? mediaStartMs;
  final int? mediaEndMs;

  /// Narrow test seams for exercising native player behaviour without a file;
  /// in production both use the real default implementation.
  @visibleForTesting
  final VideoPlayerController Function(String path)? controllerFactory;

  @visibleForTesting
  final Widget Function(VideoPlayerController controller)? videoBuilder;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _controller;
  MediaClipRange? _clip;
  bool _returningToStart = false;
  int _openRequest = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// The full file range when there is no trim. The range itself comes from
  /// the **shared** source used by the audio player ([resolveMediaClipRange]);
  /// here only the "no trim" case is turned into the concrete range video needs.
  MediaClipRange _clipFor(Duration duration) =>
      resolveMediaClipRange(
        sourceDuration: duration,
        mediaStartMs: widget.mediaStartMs,
        mediaEndMs: widget.mediaEndMs,
      ) ??
      MediaClipRange(start: Duration.zero, end: duration);

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _open();
      return;
    }
    if (oldWidget.mediaStartMs != widget.mediaStartMs ||
        oldWidget.mediaEndMs != widget.mediaEndMs) {
      _applyUpdatedClip();
    }
  }

  @override
  void dispose() {
    _openRequest += 1;
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final request = ++_openRequest;
    final previous = _controller;
    _controller = null;
    _clip = null;
    if (previous != null) {
      previous.removeListener(_onTick);
      await previous.dispose();
    }
    if (!mounted || request != _openRequest) return;
    final controller = widget.controllerFactory?.call(widget.path) ??
        VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      if (!mounted || request != _openRequest) {
        await controller.dispose();
        return;
      }
      final clip = _clipFor(controller.value.duration);
      // The first frame should be the poster of the selected section, not of
      // the file; otherwise the user would see content they cropped out.
      await controller.seekTo(clip.start);
      if (!mounted || request != _openRequest) {
        await controller.dispose();
        return;
      }
      // Rewind and stop when finished: to watch a second time the user should
      // only have to press play.
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _clip = clip;
      });
      widget.onDuration?.call(controller.value.duration);
    } catch (e) {
      debugPrint('Could not open the video: $e');
      await controller.dispose();
    }
  }

  void _onTick() {
    final c = _controller;
    final clip = _clip;
    if (c == null || clip == null) return;
    if (clip.hasReachedEnd(c.value.position) && !_returningToStart) {
      _returnToStart(c, clip);
    }
    if (mounted) setState(() {});
  }

  Future<void> _returnToStart(
    VideoPlayerController controller,
    MediaClipRange clip,
  ) async {
    _returningToStart = true;
    try {
      // `video_player` does not consider itself complete at a trim boundary.
      // Pausing first stops it from leaking a few frames of the part that was
      // cut, and seeking back to the start afterwards makes a second play
      // one tap away.
      if (controller.value.isPlaying) await controller.pause();
      await controller.seekTo(clip.start);
    } finally {
      _returningToStart = false;
      if (mounted && identical(controller, _controller)) setState(() {});
    }
  }

  Future<void> _applyUpdatedClip() async {
    final controller = _controller;
    if (controller == null) return;
    final clip = _clipFor(controller.value.duration);
    _clip = clip;
    await _returnToStart(controller, clip);
  }

  Future<void> _toggle() async {
    final c = _controller;
    final clip = _clip;
    if (c == null || clip == null || _returningToStart) return;
    if (c.value.isPlaying) {
      await c.pause();
      return;
    }
    // Platform positions can overshoot the millisecond boundary slightly.
    // Pressing play from such a position would play the uncut tail; the safe
    // start is always the one the card selected.
    if (!clip.canStartPlaybackAt(c.value.position)) {
      await c.seekTo(clip.start);
    }
    await c.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final clip = _clip;
    if (controller == null || clip == null) {
      return SizedBox(
        height: widget.maxHeight ?? 200,
        child: const ColoredBox(color: ViewfinderColors.deep),
      );
    }

    final video = AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.videoBuilder?.call(controller) ?? VideoPlayer(controller),
          // Controls do not disappear during playback: pausing by tap should
          // be as easy as starting by tap.
          Center(
            child: AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0.0 : 1.0,
              duration: AppDuration.fast,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                formatClipDuration(
                  clip.remainingAt(controller.value.position),
                ),
                style: AppText.body(
                  size: 12,
                  weight: 600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: widget.maxHeight == null
            ? video
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                child: video,
              ),
      ),
    );
  }
}

/// The `0:07` format -- audio and video should look the same everywhere.
String formatClipDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

