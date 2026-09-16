import 'package:flutter/foundation.dart';

/// The **single** interpretation of the cut points stored on a card.
///
/// Trimming does not re-encode the file: the file stays whole and the player
/// obeys the range written on the card. The audio and video players have to
/// share this interpretation. Two separate implementations can each be
/// internally consistent and still disagree at a boundary -- one dropping the
/// trim, the other clamping it -- and no test of either alone would notice.
/// So the policy lives here, in one place.
///
/// Values are **absolute milliseconds measured from the start of the file.**
/// A `null` start means the beginning of the file and a `null` end means its
/// end; both `null` means no trim was applied. Being nullable keeps older
/// cards working without a migration.
@immutable
class MediaClipRange {
  const MediaClipRange({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get duration => end - start;

  bool hasReachedEnd(Duration position) => position >= end;

  bool canStartPlaybackAt(Duration position) =>
      position >= start && position < end;

  Duration remainingAt(Duration position) {
    if (position <= start) return duration;
    if (position >= end) return Duration.zero;
    return end - position;
  }

  @override
  bool operator ==(Object other) =>
      other is MediaClipRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MediaClipRange($start, $end)';
}

/// Converts raw bounds into a range the player can safely apply.
///
/// The policy -- all three parts deliberate:
///
/// 1. **An out-of-range value is clamped, not discarded.** A negative start is
///    pulled to `0`; an end past the duration is pulled to the end of the file.
///    Silently ignoring the user's intent to trim over one bad number would
///    play the card untrimmed and leave them believing they never trimmed it
///    -- the worse lie. (An end slightly past the duration is ordinary rounding.)
/// 2. **When `start >= end` the trim is ignored.** Falling back to the whole
///    file is safer than making a card unreachable over a range that leaves no
///    playable frame. The values on the card are untouched; the user can fix them.
/// 3. **An unknown duration means no range is applied.** There is nothing to clamp to.
MediaClipRange? resolveMediaClipRange({
  required Duration? sourceDuration,
  int? mediaStartMs,
  int? mediaEndMs,
}) {
  if (mediaStartMs == null && mediaEndMs == null) return null;

  final durationMs = sourceDuration?.inMilliseconds;
  if (durationMs == null || durationMs <= 0) return null;

  final startMs = (mediaStartMs ?? 0).clamp(0, durationMs).toInt();
  final endMs = (mediaEndMs ?? durationMs).clamp(0, durationMs).toInt();
  if (startMs >= endMs) return null;
  if (startMs == 0 && endMs == durationMs) return null;

  return MediaClipRange(
    start: Duration(milliseconds: startMs),
    end: Duration(milliseconds: endMs),
  );
}
