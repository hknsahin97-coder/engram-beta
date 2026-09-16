import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../media/media_clip.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A single row that plays one audio file: play/pause, progress, duration.
///
/// A seek bar is **deliberately absent**. The audio on a review card is a note
/// a few seconds long; there is no need to scrub, and every extra control on
/// the card shifts attention from its subject to the interface.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({
    super.key,
    required this.path,
    this.onViewfinder = false,
    this.autoPlay = false,
    this.onDuration,
    this.mediaStartMs,
    this.mediaEndMs,
    this.player,
  });

  /// Reports the duration that will **actually play** when the file is opened.
  /// With a trim it is the cut range, otherwise the original file's duration.
  ///
  /// The counter kept during recording comes out shorter: it starts ticking
  /// after `start()` returns, while the encoder started slightly earlier. The
  /// duration shown in the Library must match the audio that plays.
  final ValueChanged<Duration>? onDuration;

  /// An **absolute** path. Resolving a relative path is the caller's job (`MediaStore.resolve`).
  final String path;

  /// Whether it sits on a dark surface (confirmation screen) or on the theme (review card).
  final bool onViewfinder;

  final bool autoPlay;

  /// Cut boundaries in milliseconds, relative to the original file.
  ///
  /// A `null` start means the beginning of the file and a `null` end means its
  /// end. Because the bounds are nullable on the card, older cards with no trim
  /// need no migration value.
  final int? mediaStartMs;
  final int? mediaEndMs;

  /// Exists so the platform player can be observed in a unit test without
  /// opening a real file; production always uses the `just_audio` adapter.
  @visibleForTesting
  final AudioPlayerHandle? player;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late final AudioPlayerHandle _player;
  StreamSubscription<PlayerState>? _states;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = widget.player ?? _JustAudioPlayerHandle();
    _open();
  }

  @override
  void dispose() {
    _states?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      var duration = await _player.setFilePath(widget.path);
      final clip = resolveMediaClipRange(
        sourceDuration: duration,
        mediaStartMs: widget.mediaStartMs,
        mediaEndMs: widget.mediaEndMs,
      );
      if (clip != null) {
        try {
          duration = await _player.setClip(
            start: clip.start,
            end: clip.end,
          );
        } catch (e) {
          // Even if the trim metadata or a platform detail is broken, the
          // card's audio must not become unreachable; reopening the whole file
          // is a safe fallback and kinder than silently playing nothing.
          debugPrint('Could not apply the audio trim, opening the whole file: $e');
          duration = await _player.setFilePath(widget.path);
        }
      }
      if (!mounted) return;
      setState(() => _ready = true);
      if (duration != null) widget.onDuration?.call(duration);

      _states = _player.playerStateStream.listen((state) {
        // Rewind when finished: to listen a second time the user should only
        // have to press play, not stop first and then play.
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
        if (mounted) setState(() {});
      });

      if (widget.autoPlay) await _player.play();
    } catch (e) {
      debugPrint('Could not open the audio: $e');
    }
  }

  void _toggle() {
    if (!_ready) return;
    _player.playing ? _player.pause() : _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground =
        widget.onViewfinder ? ViewfinderColors.text : palette.textPrimary;
    final muted = widget.onViewfinder
        ? ViewfinderColors.textSecondary
        : palette.textSecondary;
    final track = widget.onViewfinder ? ViewfinderColors.fill : palette.border;

    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final total = _player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final progress = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

        return Row(
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.accent,
                ),
                child: Icon(
                  _player.playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.hairline),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: track,
                  valueColor: const AlwaysStoppedAnimation(AppPalette.accent),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              _format(_ready ? (total - position) : Duration.zero),
              style: AppText.body(
                size: 13,
                weight: 500,
                color: _ready ? foreground : muted,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The narrow surface needed to test `just_audio` without a platform call.
@visibleForTesting
abstract interface class AudioPlayerHandle {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  bool get playing;
  Duration? get duration;

  Future<Duration?> setFilePath(String path);
  Future<Duration?> setClip({Duration? start, Duration? end});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class _JustAudioPlayerHandle implements AudioPlayerHandle {
  final AudioPlayer _player = AudioPlayer();

  @override
  Duration? get duration => _player.duration;

  @override
  bool get playing => _player.playing;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<Duration?> setClip({Duration? start, Duration? end}) =>
      _player.setClip(start: start, end: end);

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);
}
