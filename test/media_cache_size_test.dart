import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/media_cache_size.dart';

void main() {
  group('MediaCacheSize.fromStorage', () {
    test('parses known values', () {
      expect(MediaCacheSize.fromStorage('mb500'), MediaCacheSize.mb500);
      expect(MediaCacheSize.fromStorage('gb1'), MediaCacheSize.gb1);
      expect(MediaCacheSize.fromStorage('gb2'), MediaCacheSize.gb2);
      expect(MediaCacheSize.fromStorage('gb5'), MediaCacheSize.gb5);
    });

    test('falls back to 1 GB for unknown or missing values', () {
      expect(MediaCacheSize.fromStorage(null), MediaCacheSize.gb1);
      expect(MediaCacheSize.fromStorage(''), MediaCacheSize.gb1);
      expect(MediaCacheSize.fromStorage('500mb'), MediaCacheSize.gb1);
    });

    test('bytes match the advertised tiers', () {
      expect(MediaCacheSize.mb500.bytes, 500 * 1024 * 1024);
      expect(MediaCacheSize.gb1.bytes, 1024 * 1024 * 1024);
      expect(MediaCacheSize.gb2.bytes, 2 * 1024 * 1024 * 1024);
      expect(MediaCacheSize.gb5.bytes, 5 * 1024 * 1024 * 1024);
    });
  });
}
