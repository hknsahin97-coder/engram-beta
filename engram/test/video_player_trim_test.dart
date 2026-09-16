import 'package:engram/core/media/media_clip.dart';
import 'package:engram/core/widgets/video_player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  const sourceDuration = Duration(seconds: 10);

  group('video trim range', () {
    test('an older card with no bounds plays the whole file', () {
      final clip = _range();

      expect(clip.start, Duration.zero);
      expect(clip.end, sourceDuration);
      expect(clip.duration, sourceDuration);
    });

    test('two bounds define the selected section and the remaining duration', () {
      final clip = _range(
        mediaStartMs: 2000,
        mediaEndMs: 7500,
      );

      expect(clip.start, const Duration(seconds: 2));
      expect(clip.end, const Duration(milliseconds: 7500));
      expect(clip.duration, const Duration(milliseconds: 5500));
      expect(
        clip.remainingAt(const Duration(milliseconds: 3250)),
        const Duration(milliseconds: 4250),
      );
    });

    test('with one bound given, the other end is the file boundary', () {
      final startOnly = _range(
        mediaStartMs: 3000,
      );
      final endOnly = _range(
        mediaEndMs: 6000,
      );

      expect((
        startOnly.start,
        startOnly.end
      ), (
        const Duration(seconds: 3),
        sourceDuration,
      ));
      expect((
        endOnly.start,
        endOnly.end
      ), (
        Duration.zero,
        const Duration(seconds: 6),
      ));
    });

    test('bounds past the end of the file are squeezed into a safe range', () {
      final clip = _range(
        mediaStartMs: -400,
        mediaEndMs: 12000,
      );

      expect(clip.start, Duration.zero);
      expect(clip.end, sourceDuration);
    });

    test('an inverted or zero-length range does not make the video unreachable', () {
      for (final bounds in [(8000, 2000), (4000, 4000)]) {
        final clip = _range(
          mediaStartMs: bounds.$1,
          mediaEndMs: bounds.$2,
        );

        expect(clip.start, Duration.zero);
        expect(clip.end, sourceDuration);
      }
    });

    test('the end position restarts, and playback continues before the end', () {
      final clip = _range(
        mediaStartMs: 2000,
        mediaEndMs: 7000,
      );

      expect(
        clip.canStartPlaybackAt(const Duration(milliseconds: 6999)),
        isTrue,
      );
      expect(clip.hasReachedEnd(const Duration(milliseconds: 6999)), isFalse);
      expect(clip.canStartPlaybackAt(const Duration(seconds: 7)), isFalse);
      expect(clip.hasReachedEnd(const Duration(seconds: 7)), isTrue);
      expect(clip.remainingAt(const Duration(seconds: 7)), Duration.zero);
    });
  });

  testWidgets('the player seeks to the start and stops and rewinds at the end', (
    tester,
  ) async {
    final controller = _FakeVideoController(sourceDuration);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoPlayerView(
            path: 'test.mp4',
            mediaStartMs: 2000,
            mediaEndMs: 7000,
            controllerFactory: (_) => controller,
            videoBuilder: (_) => const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.seeks, [const Duration(seconds: 2)]);
    expect(find.text('0:05'), findsOneWidget);

    await tester.tap(find.byType(VideoPlayerView));
    await tester.pump();
    expect(controller.playCount, 1);
    expect(controller.value.isPlaying, isTrue);

    controller.advanceTo(const Duration(seconds: 7));
    await tester.pump();

    expect(controller.pauseCount, 1);
    expect(controller.seeks, [
      const Duration(seconds: 2),
      const Duration(seconds: 2),
    ]);
    expect(controller.value.position, const Duration(seconds: 2));
    expect(controller.value.isPlaying, isFalse);
  });
}

class _FakeVideoController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeVideoController(Duration duration)
      : super(
          VideoPlayerValue(
            duration: duration,
            size: const Size(160, 90),
            isInitialized: true,
          ),
        );

  final List<Duration> seeks = [];
  int playCount = 0;
  int pauseCount = 0;

  void advanceTo(Duration position) {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> seekTo(Duration moment) async {
    seeks.add(moment);
    value = value.copyWith(position: moment);
  }

  @override
  Future<void> play() async {
    playCount += 1;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  int playerId = VideoPlayerController.kUninitializedPlayerId;

  @override
  String get dataSource => '';

  @override
  Map<String, String> get httpHeaders => const {};

  @override
  DataSourceType get dataSourceType => DataSourceType.file;

  @override
  String get package => '';

  @override
  Future<Duration> get position async => value.position;

  @override
  VideoViewType get viewType => VideoViewType.textureView;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  VideoFormat? get formatHint => null;

  @override
  Future<ClosedCaptionFile> get closedCaptionFile async =>
      _EmptyClosedCaptionFile();

  @override
  VideoPlayerOptions? get videoPlayerOptions => null;

  @override
  void setCaptionOffset(Duration delay) {}

  @override
  Future<void> setClosedCaptionFile(
    Future<ClosedCaptionFile>? closedCaptionFile,
  ) async {}
}

class _EmptyClosedCaptionFile extends ClosedCaptionFile {
  @override
  List<Caption> get captions => const [];
}

/// The same as the widget's `_clipFor`: the shared policy plus turning the "no
/// trim" case into the concrete range video needs. The policy itself is tested
/// in one place, in `media_clip.dart`.
MediaClipRange _range({int? mediaStartMs, int? mediaEndMs}) =>
    resolveMediaClipRange(
      sourceDuration: const Duration(seconds: 10),
      mediaStartMs: mediaStartMs,
      mediaEndMs: mediaEndMs,
    ) ??
    const MediaClipRange(start: Duration.zero, end: Duration(seconds: 10));
