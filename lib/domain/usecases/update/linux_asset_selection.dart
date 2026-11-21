import 'package:path/path.dart' as p;

/// Supported native Linux package formats for in-app updates.
enum LinuxPackageFormat { deb, rpm }

/// A GitHub release asset reduced to the two fields the updater needs.
typedef LinuxPackageAsset = ({String url, String name});

const _x64Markers = ['x86_64', 'amd64', 'x64'];
const _arm64Markers = ['arm64', 'aarch64'];
const _otherArchMarkersForX64 = [
  'arm64',
  'aarch64',
  'armhf',
  'armv7',
  'i386',
  'i686',
  'riscv64',
  's390x',
  'ppc64',
];

/// Returns true only for HTTPS URLs hosted on GitHub release domains.
bool isAllowedGitHubDownloadUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  return host == 'github.com' ||
      host == 'githubusercontent.com' ||
      host.endsWith('.githubusercontent.com');
}

/// Picks the `.deb` or `.rpm` release asset matching [format] and [arch].
///
/// Returns `null` when no compatible asset with an allowed GitHub HTTPS URL
/// exists (e.g. an unsupported architecture like `aarch64` when only `x86_64`
/// packages are published).
LinuxPackageAsset? selectLinuxPackageAsset(
  List<Map<String, dynamic>> assets,
  LinuxPackageFormat format, {
  String arch = 'x86_64',
}) {
  final ext = '.${format.name}';
  final candidates = <LinuxPackageAsset>[];
  for (final asset in assets) {
    final name = (asset['name'] as String? ?? '').trim();
    final url = (asset['browser_download_url'] as String? ?? '').trim();
    if (name.isEmpty || !name.endsWith(ext)) continue;
    if (!isAllowedGitHubDownloadUrl(url)) continue;
    candidates.add((url: url, name: name));
  }
  if (candidates.isEmpty) return null;

  final normalizedArch = arch.trim().toLowerCase();
  if (normalizedArch == 'x86_64' ||
      normalizedArch == 'amd64' ||
      normalizedArch == 'x64') {
    for (final candidate in candidates) {
      final lower = candidate.name.toLowerCase();
      if (_x64Markers.any(lower.contains) &&
          !_otherArchMarkersForX64.any(lower.contains)) {
        return candidate;
      }
    }
    for (final candidate in candidates) {
      final lower = candidate.name.toLowerCase();
      if (!_otherArchMarkersForX64.any(lower.contains)) {
        return candidate;
      }
    }
    return null;
  }

  if (normalizedArch == 'aarch64' || normalizedArch == 'arm64') {
    for (final candidate in candidates) {
      final lower = candidate.name.toLowerCase();
      if (_arm64Markers.any(lower.contains)) {
        return candidate;
      }
    }
    return null;
  }

  return null;
}

/// Finds the `SHA256SUMS` asset URL from a GitHub release asset list, if any.
String? findChecksumAssetUrl(List<Map<String, dynamic>> assets) {
  for (final asset in assets) {
    final name = (asset['name'] as String? ?? '').trim();
    if (name != 'SHA256SUMS') continue;
    final url = (asset['browser_download_url'] as String? ?? '').trim();
    if (isAllowedGitHubDownloadUrl(url)) return url;
  }
  return null;
}

final _sha256LinePattern = RegExp(r'^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$');

/// Parses a `SHA256SUMS` text file into a `basename -> sha256 (lowercase)` map.
Map<String, String> parseSha256Sums(String content) {
  final result = <String, String>{};
  for (final line in content.split(RegExp(r'\r?\n'))) {
    final match = _sha256LinePattern.firstMatch(line);
    if (match == null) continue;
    final hash = match.group(1)!.toLowerCase();
    final rawPath = match.group(2)!.trim();
    if (rawPath.isEmpty) continue;
    final base = p.posix.basename(rawPath.replaceAll(r'\', '/'));
    if (base.isEmpty || base == '.' || base == '..') continue;
    result[base] = hash;
  }
  return result;
}
