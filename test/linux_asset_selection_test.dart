import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/update/linux_asset_selection.dart';

Map<String, dynamic> _asset(String name, {String? url}) => {
  'name': name,
  'browser_download_url':
      url ?? 'https://github.com/gmstyle/sonora/releases/download/v2.0.2/$name',
};

void main() {
  group('isAllowedGitHubDownloadUrl', () {
    test('accepts GitHub HTTPS hosts', () {
      expect(
        isAllowedGitHubDownloadUrl(
          'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora.rpm',
        ),
        isTrue,
      );
      expect(
        isAllowedGitHubDownloadUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/123',
        ),
        isTrue,
      );
      expect(
        isAllowedGitHubDownloadUrl(
          'https://release-assets.githubusercontent.com/file.deb',
        ),
        isTrue,
      );
    });

    test('rejects HTTP and non-GitHub hosts', () {
      expect(
        isAllowedGitHubDownloadUrl(
          'http://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora.rpm',
        ),
        isFalse,
      );
      expect(
        isAllowedGitHubDownloadUrl('https://evil.example.com/sonora.rpm'),
        isFalse,
      );
      expect(
        isAllowedGitHubDownloadUrl('https://notgithub.com/sonora.rpm'),
        isFalse,
      );
      expect(isAllowedGitHubDownloadUrl('not a url'), isFalse);
    });
  });

  group('selectLinuxPackageAsset', () {
    final mixedAssets = [
      _asset('app-release.apk'),
      _asset('sonora-linux-x64.tar.gz'),
      _asset('sonora_2.0.2-80_amd64.deb'),
      _asset('sonora-2.0.2-80.x86_64.rpm'),
      _asset('SHA256SUMS'),
    ];

    test('picks matching .deb on x86_64', () {
      final picked = selectLinuxPackageAsset(
        mixedAssets,
        LinuxPackageFormat.deb,
        arch: 'x86_64',
      );
      expect(picked?.name, 'sonora_2.0.2-80_amd64.deb');
    });

    test('picks matching .rpm on x86_64', () {
      final picked = selectLinuxPackageAsset(
        mixedAssets,
        LinuxPackageFormat.rpm,
        arch: 'x86_64',
      );
      expect(picked?.name, 'sonora-2.0.2-80.x86_64.rpm');
    });

    test('prefers explicit x86_64/amd64 asset over arch-neutral fallback', () {
      final picked = selectLinuxPackageAsset([
        _asset('sonora-2.0.2-80.deb'),
        _asset('sonora_2.0.2-80_amd64.deb'),
      ], LinuxPackageFormat.deb);
      expect(picked?.name, 'sonora_2.0.2-80_amd64.deb');
    });

    test(
      'falls back to arch-neutral asset when no other arch marker exists',
      () {
        final picked = selectLinuxPackageAsset([
          _asset('sonora-2.0.2-80.arm64.deb'),
          _asset('sonora-2.0.2-80.deb'),
        ], LinuxPackageFormat.deb);
        expect(picked?.name, 'sonora-2.0.2-80.deb');
      },
    );

    test('returns null on aarch64 when only x86_64 assets exist', () {
      final picked = selectLinuxPackageAsset(
        mixedAssets,
        LinuxPackageFormat.rpm,
        arch: 'aarch64',
      );
      expect(picked, isNull);
    });

    test('picks arm64 asset on aarch64 when available', () {
      final picked = selectLinuxPackageAsset(
        [
          _asset('sonora-2.0.2-80.x86_64.rpm'),
          _asset('sonora-2.0.2-80.aarch64.rpm'),
        ],
        LinuxPackageFormat.rpm,
        arch: 'aarch64',
      );
      expect(picked?.name, 'sonora-2.0.2-80.aarch64.rpm');
    });

    test('ignores assets with non-GitHub or insecure URLs', () {
      final picked = selectLinuxPackageAsset([
        _asset(
          'sonora-2.0.2-80.x86_64.rpm',
          url: 'https://evil.example.com/sonora.rpm',
        ),
        _asset(
          'sonora_2.0.2-80_amd64.deb',
          url: 'http://github.com/gmstyle/sonora/sonora.deb',
        ),
      ], LinuxPackageFormat.rpm);
      expect(picked, isNull);
    });
  });

  group('findChecksumAssetUrl & parseSha256Sums', () {
    test('finds SHA256SUMS URL when valid', () {
      final url = findChecksumAssetUrl([
        _asset('sonora-2.0.2-80.x86_64.rpm'),
        _asset('SHA256SUMS'),
      ]);
      expect(
        url,
        'https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS',
      );
    });

    test('returns null if SHA256SUMS is missing or untrusted', () {
      expect(findChecksumAssetUrl([_asset('sonora.rpm')]), isNull);
      expect(
        findChecksumAssetUrl([
          _asset('SHA256SUMS', url: 'https://evil.example.com/SHA256SUMS'),
        ]),
        isNull,
      );
    });

    test('parses standard, binary-marker, and relative-path lines', () {
      final a = 'a' * 64;
      final b = 'B' * 64;
      final parsed = parseSha256Sums('''
# comment
$a  sonora-2.0.2-80.x86_64.rpm
$b *./artifacts/sonora_2.0.2-80_amd64.deb
invalid-line
''');
      expect(parsed, {
        'sonora-2.0.2-80.x86_64.rpm': a,
        'sonora_2.0.2-80_amd64.deb': 'b' * 64,
      });
    });
  });
}
