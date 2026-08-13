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
}
