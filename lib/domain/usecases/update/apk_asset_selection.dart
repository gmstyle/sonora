/// A GitHub release asset reduced to the two fields the updater needs.
typedef ApkAsset = ({String url, String name});

const _abiMarkers = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];

bool _isAbiSplit(String name) => _abiMarkers.any(name.contains);

/// Picks the APK asset matching the device architecture.
///
/// Releases ship three APKs:
/// - `app-release.apk` (universal), uploaded first so pre-ABI-aware updaters
///   that take the first `.apk` still get a package that installs everywhere;
/// - `app-arm64-v8a-release.apk` / `app-armeabi-v7a-release.apk` for clients
///   that can pick by ABI.
///
/// [supportedAbis] is expected in the order Android reports it, which is already
/// most-preferred first. When none of them matches, the universal APK is
/// preferred over a random ABI split; if only splits are present, the first
/// APK is returned (covers older single-APK and split-only releases).
///
/// Returns `null` when the release has no APK at all, e.g. a Linux-only release.
ApkAsset? selectApkAsset(
  List<Map<String, dynamic>> assets,
  List<String> supportedAbis,
) {
  final apks = <ApkAsset>[];
  for (final asset in assets) {
    final name = asset['name'] as String? ?? '';
    if (!name.endsWith('.apk')) continue;
    apks.add((url: asset['browser_download_url'] as String? ?? '', name: name));
  }

  if (apks.isEmpty) return null;

  for (final abi in supportedAbis) {
    if (abi.isEmpty) continue;
    for (final apk in apks) {
      if (apk.name.contains(abi)) return apk;
    }
  }

  for (final apk in apks) {
    if (!_isAbiSplit(apk.name)) return apk;
  }

  return apks.first;
}
