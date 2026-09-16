import 'dart:async';

import 'package:engram/core/theme/app_theme.dart';
import 'package:engram/core/media/media_clip.dart';
import 'package:engram/core/widgets/audio_player_bar.dart';
import 'package:engram/data/models/memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('MemoryCard media cut points', () {
    test('both bounds stay null on a card with no trim', () {
      final card = MemoryCard.create(type: CardType.audio);

      expect(card.mediaStartMs, isNull);
      expect(card.mediaEndMs, isNull);
    });

    test('bounds are stored as milliseconds relative to the original file', () {
      final card = MemoryCard.create(
        type: CardType.audio,
        mediaStartMs: 1250,
        mediaEndMs: 4750,
      );

      expect(card.mediaStartMs, 1250);
      expect(card.mediaEndMs, 4750);
    });
  });

  group('resolveMediaClipRange -- the shared policy of audio and video', () {
    const dur = Duration(seconds: 10);

    test('with one bound set, the other end is the file boundary', () {
      expect(
        resolveMediaClipRange(sourceDuration: dur, mediaStartMs: 1200),
        const MediaClipRange(
          start: Duration(milliseconds: 1200),
          end: dur,
        ),
      );
      expect(
        resolveMediaClipRange(sourceDuration: dur, mediaEndMs: 6400),
        const MediaClipRange(
          start: Duration.zero,
          end: Duration(milliseconds: 6400),
        ),
      );
    });

    test('an out-of-range value is clamped and the crop is preserved', () {
      // The policy: discarding the trim entirely over one bad
      // number would play the whole file, at the cost of the user believing an
      // untrimmed card was trimmed. A negative start goes to 0, an overshoot to the end.
      expect(
        resolveMediaClipRange(
          sourceDuration: dur,
          mediaStartMs: -400,
          mediaEndMs: 4000,
        ),
        const MediaClipRange(
          start: Duration.zero,
          end: Duration(seconds: 4),
        ),
      );
      expect(
        resolveMediaClipRange(
          sourceDuration: dur,
          mediaStartMs: 2000,
          mediaEndMs: 12000,
        ),
        const MediaClipRange(start: Duration(seconds: 2), end: dur),
      );
    });

    test('a range leaving no playable frame is not a trim', () {
      for (final bounds in [(5000, 5000), (7000, 6000), (-9, -3)]) {
        expect(
          resolveMediaClipRange(
            sourceDuration: dur,
            mediaStartMs: bounds.$1,
            mediaEndMs: bounds.$2,
          ),
          isNull,
          reason: 'bounds: $bounds',
        );
      }
    });

    test('a full-file range and an unknown duration produce no trim', () {
      expect(
        resolveMediaClipRange(
          sourceDuration: dur,
          mediaStartMs: 0,
          mediaEndMs: 10000,
        ),
        isNull,
      );
      expect(
        resolveMediaClipRange(sourceDuration: null, mediaStartMs: 1000),
        isNull,
      );
    });
  });

  testWidgets('applies valid bounds to the player through setClip',
      (tester) async {
    final player = _FakeAudioPlayer(sourceDuration: const Duration(seconds: 9));
    Duration? reportedDuration;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AudioPlayerBar(
            path: 'audio.m4a',
            mediaStartMs: 1500,
            mediaEndMs: 6500,
            player: player,
            onDuration: (duration) => reportedDuration = duration,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(player.openedPaths, ['audio.m4a']);
    expect(player.clips, [
      (
        start: const Duration(milliseconds: 1500),
        end: const Duration(milliseconds: 6500)
      ),
    ]);
    expect(reportedDuration, const Duration(seconds: 5));
  });

  testWidgets('plays the whole file without calling setClip on an invalid range', (
    tester,
  ) async {
    final player = _FakeAudioPlayer(sourceDuration: const Duration(seconds: 9));
    Duration? reportedDuration;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AudioPlayerBar(
            path: 'audio.m4a',
            mediaStartMs: 7000,
            mediaEndMs: 2000,
            player: player,
            onDuration: (duration) => reportedDuration = duration,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(player.clips, isEmpty);
    expect(reportedDuration, const Duration(seconds: 9));
  });
}

class _FakeAudioPlayer implements AudioPlayerHandle {
  _FakeAudioPlayer({required this.sourceDuration});

  final Duration sourceDuration;
  final List<String> openedPaths = [];
  final List<({Duration? start, Duration? end})> clips = [];
  final _positions = StreamController<Duration>.broadcast();
  final _states = StreamController<PlayerState>.broadcast();

  @override
  Duration? duration;

  @override
  bool playing = false;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<PlayerState> get playerStateStream => _states.stream;

  @override
  Future<Duration?> setFilePath(String path) async {
    openedPaths.add(path);
    duration = sourceDuration;
    return duration;
  }

  @override
  Future<Duration?> setClip({Duration? start, Duration? end}) async {
    clips.add((start: start, end: end));
    final clipStart = start ?? Duration.zero;
    final clipEnd = end ?? sourceDuration;
    duration = clipEnd - clipStart;
    return duration;
  }

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _positions.close();
    await _states.close();
  }
}
