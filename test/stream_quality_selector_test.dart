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

    test('high picks highest bitrate muxed', () {
      final stream = selector.select(
        manifest,
        quality: MediaQuality.high,
        preferVideo: true,
      );
      expect(stream.tag, 30);
    });

    test('mid prefers medium360', () {
      final stream =
          selector.select(
                manifest,
                quality: MediaQuality.mid,
                preferVideo: true,
              )
              as MuxedStreamInfo;
      expect(stream.videoQuality, VideoQuality.medium360);
      expect(stream.tag, 30); // highest among medium360
    });

    test('low prefers low144/low240', () {
      final stream = selector.select(
        manifest,
        quality: MediaQuality.low,
        preferVideo: true,
      );
      expect(stream.tag, 10);
    });
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
}
