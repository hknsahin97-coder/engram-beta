import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Audio waveform.
///
/// **The levels are real.** The bars are fed by the instantaneous amplitude
/// reported by the `record` plugin. A fake waveform says "I am recording" but
/// not "I can hear you" -- with a dead microphone the user would only find out
/// on playback.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.levels,
    this.color = AppPalette.accent,
    this.height = 60,
    this.barCount = 24,
  });

  /// Levels in the 0..1 range, ordered **oldest to newest**.
  final List<double> levels;

  final Color color;
  final double height;

  /// How many bars are kept on screen; a short list is right-aligned.
  final int barCount;

  @override
  Widget build(BuildContext context) {
    // Fill from the right while the list is short: recording flows left to right.
    final padded = <double>[
      ...List.filled((barCount - levels.length).clamp(0, barCount), 0.0),
      ...levels.length > barCount
          ? levels.sublist(levels.length - barCount)
          : levels,
    ];

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final level in padded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 4,
                // A thin line remains even in silence: zero height read as
                // "the connection dropped".
                height: (height * level).clamp(3.0, height),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.hairline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Converts a dBFS value into the 0..1 range.
///
/// `record` reports amplitude in decibels: silence is about -60 dB and the
/// loudest sound is 0 dB. Drawn directly, the bars would sit at the ceiling
/// all the time; we take -50 dB as the floor and linearise from there.
double normalizeAmplitude(double dbfs) {
  const floor = -50.0;
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  return ((dbfs - floor) / -floor).clamp(0.0, 1.0);
}
