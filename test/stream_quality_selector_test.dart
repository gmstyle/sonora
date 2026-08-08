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

  VideoOnlyStreamInfo videoOnly(
    int tag,
    int bitrate,
    VideoQuality quality,
    VideoResolution resolution,
  ) {
    return VideoOnlyStreamInfo(
      videoId,
      tag,
      Uri.parse('https://example.com/v$tag'),
      StreamContainer.mp4,
      FileSize(3000),
      Bitrate(bitrate),
      'avc1',
      quality.name,
      quality,
      resolution,
      const Framerate(30),
      const [],
      MediaType('video', 'mp4'),
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

  group('StreamQualitySelector selectPlayback adaptive', () {
    final manifest = StreamManifest([
      audio(1, 48000),
      audio(2, 128000),
      audio(3, 256000),
      videoOnly(
        40,
        500000,
        VideoQuality.medium360,
        const VideoResolution(640, 360),
      ),
      videoOnly(
        50,
        1500000,
        VideoQuality.high720,
        const VideoResolution(1280, 720),
      ),
      videoOnly(
        60,
        3000000,
        VideoQuality.high1080,
        const VideoResolution(1920, 1080),
      ),
      videoOnly(
        70,
        8000000,
        VideoQuality.high1440,
        const VideoResolution(2560, 1440),
      ),
      muxed(
        30,
        800000,
        VideoQuality.medium360,
        const VideoResolution(640, 360),
      ),
    ]);

    test('high picks ≤1080p video + highest audio', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.high,
        videoQuality: MediaQuality.high,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isTrue);
      expect(
        (sel.primary as VideoOnlyStreamInfo).videoQuality,
        VideoQuality.high1080,
      );
      expect(sel.externalAudio!.tag, 3);
    });

    test('mid prefers 720p', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.mid,
        videoQuality: MediaQuality.mid,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isTrue);
      expect(
        (sel.primary as VideoOnlyStreamInfo).videoQuality,
        VideoQuality.high720,
      );
    });

    test('low prefers 360p', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.low,
        videoQuality: MediaQuality.low,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isTrue);
      expect(
        (sel.primary as VideoOnlyStreamInfo).videoQuality,
        VideoQuality.medium360,
      );
    });

    test('independent video mid + audio high', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.high,
        videoQuality: MediaQuality.mid,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isTrue);
      expect(
        (sel.primary as VideoOnlyStreamInfo).videoQuality,
        VideoQuality.high720,
      );
      expect(sel.externalAudio!.tag, 3);
    });

    test('independent video high + audio low', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.low,
        videoQuality: MediaQuality.high,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isTrue);
      expect(
        (sel.primary as VideoOnlyStreamInfo).videoQuality,
        VideoQuality.high1080,
      );
      expect(sel.externalAudio!.tag, 1);
    });

    test('falls back to muxed when videoOnly empty', () {
      final muxOnly = StreamManifest([
        audio(2, 128000),
        muxed(
          30,
          800000,
          VideoQuality.medium360,
          const VideoResolution(640, 360),
        ),
      ]);
      final sel = selector.selectPlayback(
        muxOnly,
        audioQuality: MediaQuality.high,
        videoQuality: MediaQuality.high,
        preferVideo: true,
      );
      expect(sel.isAdaptive, isFalse);
      expect(sel.primary, isA<MuxedStreamInfo>());
    });

    test('preferVideo false uses audioQuality only', () {
      final sel = selector.selectPlayback(
        manifest,
        audioQuality: MediaQuality.mid,
        videoQuality: MediaQuality.low,
        preferVideo: false,
      );
      expect(sel.isAdaptive, isFalse);
      expect(sel.primary, isA<AudioOnlyStreamInfo>());
      expect(sel.primary.tag, 2);
    });
  });
}
