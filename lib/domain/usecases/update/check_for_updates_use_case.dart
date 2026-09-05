import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_asset_selection.dart';
import 'release_changelog.dart';

class UpdateCheckResult {
  final String latestVersion;
  final String changelog;
  final bool isNewer;
  final String releaseAssetUrl;
  final String releaseAssetName;

  const UpdateCheckResult({
    this.latestVersion = '',
    this.changelog = '',
    this.isNewer = false,
    this.releaseAssetUrl = '',
    this.releaseAssetName = '',
  });
}

class CheckForUpdatesUseCase {
  final String repoOwner;
  final String repoName;

  /// Device ABIs, most-preferred first, used to pick the right APK from a
  /// per-ABI release. Injected so the domain layer stays free of platform
  /// channels; defaults to an empty list, which falls back to the first APK.
  final Future<List<String>> Function() _supportedAbis;

  CheckForUpdatesUseCase({
    required this.repoOwner,
    required this.repoName,
    Future<List<String>> Function()? supportedAbis,
  }) : _supportedAbis = supportedAbis ?? _noAbis;

  static Future<List<String>> _noAbis() async => const <String>[];

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

    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        ),
      );
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        client.close();
        throw HttpException(
          'Failed to check for updates: HTTP ${response.statusCode}',
          uri: Uri.parse(
            'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
          ),
        );
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String? ?? '';
      final changelog = sanitizeReleaseNotes(data['body'] as String? ?? '');
      final assets = (data['assets'] as List<dynamic>?) ?? [];

      final isNewer = _isRemoteVersionNewer(latestTag, currentVersion);

      final apk = selectApkAsset(
        assets.cast<Map<String, dynamic>>(),
        await _supportedAbis(),
      );
      final assetUrl = apk?.url ?? '';
      final assetName = apk?.name ?? '';

      return UpdateCheckResult(
        latestVersion: latestTag,
        changelog: changelog,
        isNewer: isNewer,
        releaseAssetUrl: assetUrl,
        releaseAssetName: assetName,
      );
    } catch (e) {
      rethrow;
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

    final filePath = '${dir.path}/$fileName';
    final dio = Dio();

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
