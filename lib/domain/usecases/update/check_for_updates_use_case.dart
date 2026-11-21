import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'apk_asset_selection.dart';
import 'linux_asset_selection.dart';
import 'release_changelog.dart';

/// How an available update should be installed on the current host.
enum UpdateInstallTarget { androidApk, linuxDeb, linuxRpm, manual }

/// Host platform abstraction so update selection tests do not depend on OS globals.
enum UpdateHostPlatform { android, linux, other }

/// Thrown when a downloaded Linux package fails SHA-256 verification.
class UpdateChecksumException implements Exception {
  final String message;

  const UpdateChecksumException(this.message);

  @override
  String toString() => 'UpdateChecksumException: $message';
}

class UpdateCheckResult {
  final String latestVersion;
  final String changelog;
  final bool isNewer;
  final String releaseAssetUrl;
  final String releaseAssetName;
  final UpdateInstallTarget installTarget;
  final String checksumAssetUrl;

  const UpdateCheckResult({
    this.latestVersion = '',
    this.changelog = '',
    this.isNewer = false,
    this.releaseAssetUrl = '',
    this.releaseAssetName = '',
    this.installTarget = UpdateInstallTarget.manual,
    this.checksumAssetUrl = '',
  });
}

class CheckForUpdatesUseCase {
  final String repoOwner;
  final String repoName;

  /// Device ABIs, most-preferred first, used to pick the right APK from a
  /// per-ABI release. Injected so the domain layer stays free of platform
  /// channels; defaults to an empty list, which falls back to the first APK.
  final Future<List<String>> Function() _supportedAbis;

  /// Native Linux package format and architecture if the running install is
  /// upgradable in-place; returns `null` when manual browser download applies.
  final Future<({LinuxPackageFormat format, String arch})?> Function()
  _linuxInstallTarget;

  final UpdateHostPlatform _hostPlatform;
  final Dio Function() _createDio;
  final Future<String> Function(Uri uri)? _fetchJson;

  CheckForUpdatesUseCase({
    required this.repoOwner,
    required this.repoName,
    Future<List<String>> Function()? supportedAbis,
    Future<({LinuxPackageFormat format, String arch})?> Function()?
    linuxInstallTarget,
    UpdateHostPlatform? hostPlatform,
    Dio Function()? dioFactory,
    this._fetchJson,
  }) : _supportedAbis = supportedAbis ?? _noAbis,
       _linuxInstallTarget = linuxInstallTarget ?? _noLinuxTarget,
       _hostPlatform = hostPlatform ?? _detectHostPlatform(),
       _createDio = dioFactory ?? Dio.new;

  static Future<List<String>> _noAbis() async => const <String>[];

  static Future<({LinuxPackageFormat format, String arch})?>
  _noLinuxTarget() async => null;

  static UpdateHostPlatform _detectHostPlatform() {
    if (Platform.isAndroid) return UpdateHostPlatform.android;
    if (Platform.isLinux) return UpdateHostPlatform.linux;
    return UpdateHostPlatform.other;
  }

  Future<UpdateCheckResult> execute({
    required String currentVersion,
    int? lastCheckEpochMillis,
  }) async {
    if (lastCheckEpochMillis != null) {
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - lastCheckEpochMillis;
      if (elapsed < const Duration(hours: 24).inMilliseconds) {
        return const UpdateCheckResult();
      }
    }

    final uri = Uri.parse(
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
    );

    final body = _fetchJson != null
        ? await _fetchJson(uri)
        : await _defaultFetchJson(uri);

    final data = jsonDecode(body) as Map<String, dynamic>;
    final latestTag = data['tag_name'] as String? ?? '';
    final changelog = sanitizeReleaseNotes(data['body'] as String? ?? '');
    final assets = ((data['assets'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final isNewer = _isRemoteVersionNewer(latestTag, currentVersion);
    final checksumUrl = findChecksumAssetUrl(assets) ?? '';

    var installTarget = UpdateInstallTarget.manual;
    var assetUrl = '';
    var assetName = '';

    if (isNewer && _hostPlatform == UpdateHostPlatform.android) {
      final apk = selectApkAsset(assets, await _supportedAbis());
      if (apk != null) {
        installTarget = UpdateInstallTarget.androidApk;
        assetUrl = apk.url;
        assetName = apk.name;
      }
    } else if (isNewer && _hostPlatform == UpdateHostPlatform.linux) {
      final linuxTarget = await _linuxInstallTarget();
      if (linuxTarget != null) {
        final pkg = selectLinuxPackageAsset(
          assets,
          linuxTarget.format,
          arch: linuxTarget.arch,
        );
        if (pkg != null) {
          installTarget = linuxTarget.format == LinuxPackageFormat.deb
              ? UpdateInstallTarget.linuxDeb
              : UpdateInstallTarget.linuxRpm;
          assetUrl = pkg.url;
          assetName = pkg.name;
        }
      }
    }

    return UpdateCheckResult(
      latestVersion: latestTag,
      changelog: changelog,
      isNewer: isNewer,
      releaseAssetUrl: assetUrl,
      releaseAssetName: assetName,
      installTarget: installTarget,
      checksumAssetUrl: checksumUrl,
    );
  }

  Future<String> _defaultFetchJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to check for updates: HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  Future<String> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getDownloadsDirectory();
    if (dir == null) {
      throw Exception('Downloads directory not available');
    }

    final filePath = p.join(dir.path, fileName);
    final dio = _createDio();

    await dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return filePath;
  }

  /// Downloads a Linux `.deb` or `.rpm` package into a fresh temporary directory
  /// and verifies its SHA-256 checksum when [checksumAssetUrl] is provided.
  Future<String> downloadLinuxPackage(
    String url,
    String fileName, {
    String checksumAssetUrl = '',
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
  }) async {
    if (!isAllowedGitHubDownloadUrl(url)) {
      throw ArgumentError.value(url, 'url', 'Disallowed download URL');
    }
    if (checksumAssetUrl.isNotEmpty &&
        !isAllowedGitHubDownloadUrl(checksumAssetUrl)) {
      throw ArgumentError.value(
        checksumAssetUrl,
        'checksumAssetUrl',
        'Disallowed checksum URL',
      );
    }

    final safeName = p.posix.basename(fileName.trim());
    if (safeName.isEmpty ||
        safeName == '.' ||
        safeName == '..' ||
        (!safeName.endsWith('.deb') && !safeName.endsWith('.rpm'))) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid package name');
    }

    final tempDir = await Directory.systemTemp.createTemp('sonora-update-');
    final filePath = p.join(tempDir.path, safeName);
    final dio = _createDio();

    try {
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      if (checksumAssetUrl.isNotEmpty) {
        onVerifying?.call();
        final response = await dio.get<String>(
          checksumAssetUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final sums = parseSha256Sums(response.data ?? '');
        final expectedHash = sums[safeName];
        if (expectedHash == null) {
          throw UpdateChecksumException(
            'Missing SHA-256 entry for $safeName in SHA256SUMS',
          );
        }
        final digest = await sha256.bind(File(filePath).openRead()).first;
        final actualHash = digest.toString().toLowerCase();
        if (actualHash != expectedHash) {
          throw UpdateChecksumException(
            'SHA-256 mismatch for $safeName: expected $expectedHash, got $actualHash',
          );
        }
      }

      return filePath;
    } catch (_) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  bool _isRemoteVersionNewer(String remoteTag, String localVersion) {
    final remote = _parseSemver(_stripVersionPrefix(remoteTag));
    final local = _parseSemver(_stripVersionPrefix(localVersion));
    final length = remote.length > local.length ? remote.length : local.length;
    for (var i = 0; i < length; i++) {
      final r = i < remote.length ? remote[i] : 0;
      final l = i < local.length ? local[i] : 0;
      if (r != l) return r > l;
    }
    return false;
  }

  String _stripVersionPrefix(String version) {
    var v = version;
    if (v.startsWith('v')) v = v.substring(1);
    return v.replaceAll('+', '.');
  }

  List<int> _parseSemver(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }
}
