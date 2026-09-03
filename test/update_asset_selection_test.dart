import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/update/apk_asset_selection.dart';

Map<String, dynamic> asset(String name) => {
  'name': name,
  'browser_download_url': 'https://example.com/$name',
};

void main() {
  group('selectApkAsset', () {
    final splitRelease = [
      asset('sonora-1.7.4-60.deb'),
      asset('app-arm64-v8a-release.apk'),
      asset('app-armeabi-v7a-release.apk'),
    ];

    test('picks arm64 when the device prefers arm64', () {
      final picked = selectApkAsset(splitRelease, ['arm64-v8a', 'armeabi-v7a']);

      expect(picked?.name, 'app-arm64-v8a-release.apk');
      expect(picked?.url, 'https://example.com/app-arm64-v8a-release.apk');
    });

    test('picks armeabi-v7a on a 32-bit device', () {
      final picked = selectApkAsset(splitRelease, ['armeabi-v7a']);

      expect(picked?.name, 'app-armeabi-v7a-release.apk');
    });

    test('honours ABI order rather than asset order', () {
      // arm64 comes first in the asset list, but the device prefers v7a.
      final picked = selectApkAsset(splitRelease, ['armeabi-v7a', 'arm64-v8a']);

      expect(picked?.name, 'app-armeabi-v7a-release.apk');
    });

    test('falls back to the first APK when the ABI list is empty', () {
      final picked = selectApkAsset(splitRelease, const []);

      expect(picked?.name, 'app-arm64-v8a-release.apk');
    });

    test('falls back to the first APK when no ABI matches', () {
      final picked = selectApkAsset(splitRelease, ['riscv64']);

      expect(picked?.name, 'app-arm64-v8a-release.apk');
    });

    test('returns null when the release ships no APK', () {
      final picked = selectApkAsset(
        [
          asset('sonora-1.7.4-60.deb'),
          asset('sonora-1.7.4-60.x86_64.rpm'),
          asset('sonora-linux-x64.tar.gz'),
        ],
        ['arm64-v8a'],
      );

      expect(picked, isNull);
    });

    test('returns null for an empty asset list', () {
      expect(selectApkAsset(const [], const ['arm64-v8a']), isNull);
    });

    test('older universal releases stay updatable', () {
      // Releases published before the per-ABI split carry a single
      // app-release.apk, which matches no ABI string.
      final picked = selectApkAsset(
        [asset('app-release.apk')],
        ['arm64-v8a', 'armeabi-v7a'],
      );

      expect(picked?.name, 'app-release.apk');
    });

    test('tolerates assets with missing fields', () {
      final picked = selectApkAsset(
        [<String, dynamic>{}, asset('app-arm64-v8a-release.apk')],
        ['arm64-v8a'],
      );

      expect(picked?.name, 'app-arm64-v8a-release.apk');
    });

    test('ignores empty ABI strings', () {
      final picked = selectApkAsset(splitRelease, ['', 'armeabi-v7a']);

      expect(picked?.name, 'app-armeabi-v7a-release.apk');
    });
  });
}
