import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../repositories/library_repository.dart';
import '../../../data/datasources/remote/stream_datasource.dart';

class StartDownloadUseCase {
  final StreamDatasource _streamDatasource;
  final Dio _dio;
  final LibraryRepository _libraryRepository;

  StartDownloadUseCase(
    this._streamDatasource,
    this._dio,
    this._libraryRepository,
  );

  Future<String> execute({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    bool downloadOnlyOnWifi = false,
    String? downloadPath,
    required void Function(double progress) onProgress,
  }) async {
    if (downloadOnlyOnWifi) {
      final results = await Connectivity().checkConnectivity();
      final onWifi = results.any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
      );
      if (!onWifi) {
        throw Exception('Downloads are restricted to WiFi only.');
      }
    }

    await _libraryRepository.insertDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      status: 'downloading',
    );

    final manifest = await _streamDatasource.getManifest(videoId);
    final audio = manifest.muxed.withHighestBitrate();

    final downloadDir = await _resolveDownloadDir(downloadPath);
    final ext = audio.container.name;
    final safeName = _sanitizeFilename(title);
    final filePath = '${downloadDir.path}/$safeName-$videoId.$ext';

    await _dio.download(
      audio.url.toString(),
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

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
    );

    return filePath;
  }

  Future<Directory> _resolveDownloadDir(String? customPath) async {
    final basePath =
        (customPath != null && customPath.isNotEmpty)
            ? customPath
            : '${(await getDownloadsDirectory())?.path}/Sonora';
    final dir = Directory(basePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
