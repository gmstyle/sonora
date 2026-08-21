import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:sonora/domain/media/stream_quality_selector.dart';
import 'package:sonora/domain/models/media_quality.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  const selector = StreamQualitySelector();
  final videoId = VideoId('dQw4w9WgXcQ');
  final codec = MediaType('audio', 'mp4');

  AudioOnlyStreamInfo audio(int tag, int bitrate) {
    return AudioOnlyStreamInfo(
      videoId,
      tag,
      Uri.parse('https://example.com/a$tag'),
      StreamContainer.mp4,
      FileSize(1000),
      Bitrate(bitrate),
      'mp4a.40.2',
      '${bitrate ~/ 1000}kbps',
      const [],
      codec,
      null,
    );
  }

  VideoOnlyStreamInfo videoOnly({
    required int tag,
    required int bitrate,
    required VideoQuality quality,
    required VideoResolution resolution,
    StreamContainer container = StreamContainer.mp4,
  }) {
    return VideoOnlyStreamInfo(
      videoId,
      tag,
      Uri.parse('https://example.com/v$tag'),
      container,
      FileSize(5000),
      Bitrate(bitrate),
      'avc1',
      quality.name,
      quality,
      resolution,
      const Framerate(30),
      const [],
      MediaType('video', container.name),
    );
  }

  MuxedStreamInfo muxed(
    int tag,
    int bitrate,
    VideoQuality quality,
    VideoResolution resolution,
  ) {
    return MuxedStreamInfo(
      videoId,
      tag,
      Uri.parse('https://example.com/m$tag'),
      StreamContainer.mp4,
      FileSize(2000),
      Bitrate(bitrate),
      'mp4a.40.2',
      'avc1',
      quality.name,
      quality,
      resolution,
      const Framerate(30),
      codec,
    );
  }

  group('StreamQualitySelector audioOnly', () {
    final manifest = StreamManifest([
      audio(1, 48000),
      audio(2, 128000),
      audio(3, 256000),
    ]);

    test('high picks highest bitrate', () {
      final stream = selector.select(
        manifest,
        quality: MediaQuality.high,
        preferVideo: false,
      );
      expect(stream.tag, 3);
    });

    test('mid picks middle bitrate', () {
      final stream = selector.select(
        manifest,
        quality: MediaQuality.mid,
        preferVideo: false,
      );
      expect(stream.tag, 2);
    });

    test('low picks lowest bitrate', () {
      final stream = selector.select(
        manifest,
        quality: MediaQuality.low,
        preferVideo: false,
      );
      expect(stream.tag, 1);
    });
  });

  group('StreamQualitySelector muxed', () {
    final manifest = StreamManifest([
      muxed(10, 300000, VideoQuality.low144, const VideoResolution(256, 144)),
      muxed(
        20,
        500000,
        VideoQuality.medium360,
        const VideoResolution(640, 360),
      ),
      muxed(
        30,
        800000,
        VideoQuality.medium360,
        const VideoResolution(640, 360),
      ),
    ]);

    test(
      'preferVideo always picks highest bitrate muxed regardless of quality',
      () {
        for (final quality in MediaQuality.values) {
          final stream = selector.select(
            manifest,
            quality: quality,
            preferVideo: true,
          );
          expect(stream.tag, 30, reason: 'quality=$quality');
        }
      },
    );
  });

  group('StreamQualitySelector fallback', () {
    test('falls back to audioOnly when muxed empty', () {
      final manifest = StreamManifest([audio(5, 160000)]);
      final stream = selector.select(
        manifest,
        quality: MediaQuality.high,
        preferVideo: true,
      );
      expect(stream.tag, 5);
    });

    test('falls back to muxed when audioOnly empty', () {
      final manifest = StreamManifest([
        muxed(
          7,
          400000,
          VideoQuality.medium360,
          const VideoResolution(640, 360),
        ),
      ]);
      final stream = selector.select(
        manifest,
        quality: MediaQuality.high,
        preferVideo: false,
      );
      expect(stream.tag, 7);
    });

    test('throws when no streams', () {
      final manifest = StreamManifest(const []);
      expect(
        () => selector.select(
          manifest,
          quality: MediaQuality.high,
          preferVideo: false,
        ),
        throwsStateError,
      );
    });
  });

  group('selectAdaptiveCachePair', () {
    test('caps video at 720p and prefers mp4', () {
      final manifest = StreamManifest([
        videoOnly(
          tag: 101,
          bitrate: 900000,
          quality: VideoQuality.high1080,
          resolution: const VideoResolution(1920, 1080),
        ),
        videoOnly(
          tag: 102,
          bitrate: 500000,
          quality: VideoQuality.high720,
          resolution: const VideoResolution(1280, 720),
        ),
        videoOnly(
          tag: 103,
          bitrate: 700000,
          quality: VideoQuality.high720,
          resolution: const VideoResolution(1280, 720),
          container: StreamContainer.webM,
        ),
        audio(1, 48000),
        audio(2, 256000),
      ]);

      final pair = selector.selectAdaptiveCachePair(
        manifest,
        audioQuality: MediaQuality.high,
      );
      expect(pair, isNotNull);
      expect(pair!.video.tag, 102);
      expect(pair.video.container, StreamContainer.mp4);
      expect(pair.audio.tag, 2);
    });

    test('falls back to webm when no mp4 video-only exists', () {
      final manifest = StreamManifest([
        videoOnly(
          tag: 201,
          bitrate: 400000,
          quality: VideoQuality.high720,
          resolution: const VideoResolution(1280, 720),
          container: StreamContainer.webM,
        ),
        audio(9, 128000),
      ]);

      final pair = selector.selectAdaptiveCachePair(
        manifest,
        audioQuality: MediaQuality.high,
      );
      expect(pair, isNotNull);
      expect(pair!.video.tag, 201);
      expect(pair.video.container, StreamContainer.webM);
    });

    test('returns null when audio-only is missing', () {
      final manifest = StreamManifest([
        videoOnly(
          tag: 301,
          bitrate: 400000,
          quality: VideoQuality.high720,
          resolution: const VideoResolution(1280, 720),
        ),
      ]);
      expect(
        selector.selectAdaptiveCachePair(
          manifest,
          audioQuality: MediaQuality.high,
        ),
        isNull,
      );
    });
  });
}
