import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/services/media_cache_service.dart';

void main() {
  group('MediaCacheService.isMediaCacheUri', () {
    test('detects posix cache paths', () {
      expect(
        MediaCacheService.isMediaCacheUri(
          'file:///tmp/sonora_media_cache/abc.webm',
        ),
        isTrue,
      );
    });

    test('detects windows cache paths', () {
      expect(
        MediaCacheService.isMediaCacheUri(
          r'file:///C:\Temp\sonora_media_cache\abc.mp3',
        ),
        isTrue,
      );
    });

    test('rejects library download paths', () {
      expect(
        MediaCacheService.isMediaCacheUri('file:///storage/Sonora/abc.webm'),
        isFalse,
      );
    });

    test('rejects remote and empty URLs', () {
      expect(MediaCacheService.isMediaCacheUri(null), isFalse);
      expect(MediaCacheService.isMediaCacheUri(''), isFalse);
      expect(
        MediaCacheService.isMediaCacheUri('https://googlevideo.com/v'),
        isFalse,
      );
    });
  });

  group('MediaCacheService URI kind helpers', () {
    const muxed = 'file:///tmp/sonora_media_cache/vid.mp4';
    const videoOnly = 'file:///tmp/sonora_media_cache/vid.v.mp4';
    const videoOnlyWebm = 'file:///tmp/sonora_media_cache/vid.v.webm';
    const audioWebm = 'file:///tmp/sonora_media_cache/vid.webm';
    const audioMp3 = 'file:///tmp/sonora_media_cache/vid.mp3';

    test('isMuxedCacheUri accepts {id}.mp4 and rejects {id}.v.mp4', () {
      expect(MediaCacheService.isMuxedCacheUri(muxed), isTrue);
      expect(MediaCacheService.isMuxedCacheUri(videoOnly), isFalse);
      expect(MediaCacheService.isMuxedCacheUri(audioWebm), isFalse);
    });

    test('isVideoOnlyCacheUri detects .v. prefix after the id', () {
      expect(MediaCacheService.isVideoOnlyCacheUri(videoOnly), isTrue);
      expect(MediaCacheService.isVideoOnlyCacheUri(videoOnlyWebm), isTrue);
      expect(MediaCacheService.isVideoOnlyCacheUri(muxed), isFalse);
      expect(MediaCacheService.isVideoOnlyCacheUri(audioWebm), isFalse);
    });

    test('isAudioOnlyCacheUri is webm/mp3 and never video-only', () {
      expect(MediaCacheService.isAudioOnlyCacheUri(audioWebm), isTrue);
      expect(MediaCacheService.isAudioOnlyCacheUri(audioMp3), isTrue);
      expect(MediaCacheService.isAudioOnlyCacheUri(videoOnlyWebm), isFalse);
      expect(MediaCacheService.isAudioOnlyCacheUri(muxed), isFalse);
      expect(MediaCacheService.isAudioOnlyCacheUri(videoOnly), isFalse);
    });

    test('audio preferVideo requires audio-only, not muxed or video-only', () {
      expect(
        MediaCacheService.isCacheCompatibleWithPreferVideo(audioWebm, false),
        isTrue,
      );
      expect(
        MediaCacheService.isCacheCompatibleWithPreferVideo(muxed, false),
        isFalse,
      );
      expect(
        MediaCacheService.isCacheCompatibleWithPreferVideo(videoOnly, false),
        isFalse,
      );
    });

    test('video preferVideo accepts muxed without a sibling file', () {
      expect(
        MediaCacheService.isCacheCompatibleWithPreferVideo(muxed, true),
        isTrue,
      );
    });
  });
}
