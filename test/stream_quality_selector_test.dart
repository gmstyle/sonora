import 'dart:typed_data';

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
      final stream = selector.select(manifest, quality: MediaQuality.high);
      expect(stream.tag, 3);
    });

    test('mid picks middle bitrate', () {
      final stream = selector.select(manifest, quality: MediaQuality.mid);
      expect(stream.tag, 2);
    });

    test('low picks lowest bitrate', () {
      final stream = selector.select(manifest, quality: MediaQuality.low);
      expect(stream.tag, 1);
    });
  });

  group('StreamQualitySelector fallback', () {
    test('uses audioOnly when muxed is empty', () {
      final manifest = StreamManifest([audio(5, 160000)]);
      final stream = selector.select(manifest, quality: MediaQuality.high);
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
      final stream = selector.select(manifest, quality: MediaQuality.high);
      expect(stream.tag, 7);
    });

    test('throws when no streams', () {
      final manifest = StreamManifest(const []);
      expect(
        () => selector.select(manifest, quality: MediaQuality.high),
        throwsStateError,
      );
    });
  });

  group('StreamQualitySelector SABR fallback', () {
    SabrAudioStreamInfo sabrAudio(int tag, int bitrate) {
      final bootstrap = SabrBootstrap(
        videoId: videoId.value,
        serverAbrStreamingUrl: 'https://rr1.googlevideo.com/videoplayback?id=1',
        videoPlaybackUstreamerConfig: Uint8List.fromList([1, 2]),
        clientNameId: 101,
        clientVersion: '1.02',
        audioFormat: SabrFormatId(tag, lastModified: 1700000),
        discardVideoFormat: const SabrFormatId(160, lastModified: 1700000),
        discardVideoHeight: 144,
        durationMs: 60000,
        contentLengthBytes: 100000,
        mimeType: 'audio/webm',
      );
      return SabrAudioStreamInfo(
        videoId,
        tag,
        Uri.parse('https://rr1.googlevideo.com/videoplayback?id=1'),
        StreamContainer.webM,
        FileSize(100000),
        Bitrate(bitrate),
        'opus',
        '${bitrate ~/ 1000}kbps',
        const [],
        MediaType('audio', 'webm'),
        null,
        bootstrap,
        const Duration(seconds: 60),
      );
    }

    test('selects sabrAudio by quality tier when audioOnly is empty', () {
      final manifest = StreamManifest([
        sabrAudio(249, 50000),
        sabrAudio(250, 70000),
        sabrAudio(251, 160000),
      ]);

      expect(selector.select(manifest, quality: MediaQuality.high).tag, 251);
      expect(selector.select(manifest, quality: MediaQuality.mid).tag, 250);
      expect(selector.select(manifest, quality: MediaQuality.low).tag, 249);
    });
  });
}
