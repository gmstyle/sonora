/// A GitHub release asset reduced to the two fields the updater needs.
typedef ApkAsset = ({String url, String name});

/// Picks the APK asset matching the device architecture.
///
/// Releases ship one APK per ABI (`app-arm64-v8a-release.apk`,
/// `app-armeabi-v7a-release.apk`), so the updater can no longer take whichever
/// `.apk` comes first.
///
/// [supportedAbis] is expected in the order Android reports it, which is already
/// most-preferred first. When none of them matches, the first APK is returned:
/// releases published before the per-ABI split contain a single universal
/// `app-release.apk`, and an `armeabi-v7a` build still runs on an arm64 device.
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

  return apks.first;
}
