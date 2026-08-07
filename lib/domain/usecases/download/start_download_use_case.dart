import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../media/stream_quality_selector.dart';
import '../../models/media_quality.dart';
import '../../repositories/library_repository.dart';
import '../../../data/datasources/remote/stream_datasource.dart';
import 'download_exceptions.dart';

class StartDownloadUseCase {
  final StreamDatasource _streamDatasource;
  final Dio _dio;
  final LibraryRepository _libraryRepository;
  final StreamQualitySelector _selector;

  StartDownloadUseCase(
    this._streamDatasource,
    this._dio,
    this._libraryRepository, {
    StreamQualitySelector? selector,
  }) : _selector = selector ?? const StreamQualitySelector();

  Future<String> execute({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    bool downloadOnlyOnWifi = false,
    String? downloadPath,
    String? subdirectory,
    bool isVideo = false,
    bool isExplicit = false,
    MediaQuality quality = MediaQuality.high,
    CancelToken? cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    if (downloadOnlyOnWifi) {
      final results = await Connectivity().checkConnectivity();
      final onWifi = results.any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
      );
      if (!onWifi) throw const DownloadWifiRestrictionException();
    }

    final manifest = await _streamDatasource.getManifest(videoId);
    final stream = _selector.select(
      manifest,
      quality: quality,
      preferVideo: isVideo,
    );

    final downloadDir = await _resolveDownloadDir(
      downloadPath,
      subdirectory: subdirectory,
    );
    final ext = stream.container.name;
    final safeName = _sanitizeFilename(title);
    final filePath = '${downloadDir.path}/$safeName-$videoId.$ext';

    await _libraryRepository.insertDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      status: 'downloading',
      localPath: filePath,
      format: ext,
      isVideo: isVideo,
      isExplicit: isExplicit,
    );

    try {
      await _dio.download(
        stream.url.toString(),
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received, total);
        },
      );
    } on DioException catch (e) {
      await _cleanupOnFailure(videoId, filePath);
      if (CancelToken.isCancel(e)) throw const DownloadCancelledException();
      rethrow;
    } catch (_) {
      await _cleanupOnFailure(videoId, filePath);
      rethrow;
    }

    final file = File(filePath);
    await _libraryRepository.insertDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      status: 'completed',
      localPath: filePath,
      format: ext,
      fileSize: await file.length(),
      downloadedAt: DateTime.now(),
      isVideo: isVideo,
      isExplicit: isExplicit,
    );

    return filePath;
  }

  Future<void> _cleanupOnFailure(String videoId, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      await _libraryRepository.deleteDownload(videoId);
    } catch (_) {}
  }

  Future<Directory> _resolveDownloadDir(
    String? customPath, {
    String? subdirectory,
  }) async {
    final basePath =
        (customPath != null && customPath.isNotEmpty)
            ? customPath
            : '${(await getDownloadsDirectory())?.path}/Sonora';
    var dir = Directory(basePath);
    if (subdirectory != null) {
      dir = Directory('${dir.path}/${_sanitizeFilename(subdirectory)}');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
