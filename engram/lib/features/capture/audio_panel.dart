import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/waveform.dart';
import '../../l10n/app_localizations.dart';
import 'audio_confirm_screen.dart';

/// Audio mode -- press and hold, speak, release.
///
/// ## Why press and hold
/// Tap-to-start/tap-to-stop is less tiring but loses something: the user can
/// forget that recording is still running, and it keeps going as the phone
/// goes into a pocket. With press and hold, recording ends the moment the
/// finger lifts -- no ambiguity.
///
/// ## Permission
/// Microphone permission is requested **on the first press**, not on swiping
/// into the mode. `record`'s `hasPermission()` both asks and answers.
class AudioPanel extends ConsumerStatefulWidget {
  const AudioPanel({super.key, required this.isActive});

  final bool isActive;

  @override
  ConsumerState<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends ConsumerState<AudioPanel> {
  /// A recording shorter than this counts as an accidental tap. A half-second
  /// card is no use to anyone, and the user would not understand what happened.
  static const Duration _minimumClip = Duration(milliseconds: 500);

  final _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudes;
  Timer? _ticker;

  final List<double> _levels = [];
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _denied = false;

  @override
  void didUpdateWidget(AudioPanel old) {
    super.didUpdateWidget(old);
    // A recording still in hand has to be stopped when leaving the mode: a
    // microphone running in the background is worse than a camera left open.
    if (old.isActive && !widget.isActive && _recording) _cancel();
  }

  @override
  void dispose() {
    _amplitudes?.cancel();
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_recording) return;

    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _denied = true);
      return;
    }

    final tmp = await getTemporaryDirectory();
    final path = p.join(
      tmp.path,
      'audio_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );

    try {
      await _recorder.start(const RecordConfig(), path: path);
    } catch (e) {
      debugPrint('Could not start recording: $e');
      return;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _recording = true;
      _denied = false;
      _levels.clear();
      _elapsed = Duration.zero;
    });

    _amplitudes = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      if (!mounted) return;
      setState(() => _levels.add(normalizeAmplitude(amp.current)));
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() => _elapsed += const Duration(milliseconds: 200));
      }
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    final tooShort = _elapsed < _minimumClip;

    await _amplitudes?.cancel();
    _ticker?.cancel();
    final path = await _recorder.stop();

    if (!mounted) return;
    setState(() => _recording = false);
    HapticFeedback.lightImpact();

    if (path == null) return;
    if (tooShort) {
      // The file is not kept: an unused recording should not sit on disk.
      await File(path).delete().catchError((_) => File(path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).recordTooShort)),
        );
      }
      return;
    }

    await AudioConfirmScreen.open(
      context,
      File(path),
      duration: _elapsed,
      levels: List.of(_levels),
    );
  }

  /// Cancel the recording if the finger slides off the button -- the file goes too.
  Future<void> _cancel() async {
    if (!_recording) return;
    await _amplitudes?.cancel();
    _ticker?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      await File(path).delete().catchError((_) => File(path));
    }
    if (mounted) setState(() => _recording = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Stack(
      children: [
        Align(
          // The centre sits at 46% -- just above the middle.
          alignment: const Alignment(0, -0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Waveform(levels: _levels),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _formatDuration(_elapsed),
                style: AppText.body(
                  size: 15,
                  weight: 600,
                  color: ViewfinderColors.text,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _denied
                      ? l10n.permMicDenied
                      : (_recording ? l10n.recordReleaseHint : l10n.recordHint),
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    size: 13,
                    weight: 500,
                    color: ViewfinderColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _MicButton(
                  recording: _recording,
                  onPressStart: _start,
                  onPressEnd: _stop,
                  onCancel: _cancel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The microphone button: 78dp, red, with a ring.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onCancel,
  });

  final bool recording;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onPressStart(),
      onPointerUp: (_) => onPressEnd(),
      // Sliding off the button cancels: there is no rule saying "slide your
      // finger to finish the recording", but a finger that slips by accident
      // should not finish it either.
      onPointerCancel: (_) => onCancel(),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 78,
        height: 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ViewfinderColors.record,
          border: Border.all(
            color: ViewfinderColors.record.withValues(alpha: 0.35),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: ViewfinderColors.record.withValues(
                alpha: recording ? 0.35 : 0.12,
              ),
              blurRadius: 0,
              spreadRadius: recording ? 14 : 8,
            ),
          ],
        ),
        child: const Text('●', style: TextStyle(fontSize: 26, color: Colors.white)),
      ),
    );
  }
}
