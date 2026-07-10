import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class MediaCacheService {
  static final MediaCacheService instance = MediaCacheService._internal();
  MediaCacheService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};

  Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/sonora_media_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<String?> getCachedFileUri(String videoId) async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync();
      for (final entity in files) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          if (name.startsWith('$videoId.') && !name.endsWith('.tmp')) {
            return entity.uri.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheService] getCachedFileUri error: $e');
    }
    return null;
  }

  Future<void> downloadToCache(String videoId, String streamUrl) async {
    if (_activeDownloads.containsKey(videoId)) return;
    final existing = await getCachedFileUri(videoId);
    if (existing != null) return;

    final cancelToken = CancelToken();
    _activeDownloads[videoId] = cancelToken;

    try {
      final cacheDir = await _getCacheDir();
      final ext = streamUrl.contains('mime=audio%2Fwebm') ? 'webm' : 'mp3';
      final tempFilePath = '${cacheDir.path}/$videoId.tmp';
      final finalFilePath = '${cacheDir.path}/$videoId.$ext';

      debugPrint('[MediaCacheService] Starting cache download for $videoId...');
      await _dio.download(streamUrl, tempFilePath, cancelToken: cancelToken);

      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.rename(finalFilePath);
        debugPrint('[MediaCacheService] Cache download complete for $videoId');
      }
    } catch (e) {
      debugPrint('[MediaCacheService] Cache download failed for $videoId: $e');
      try {
        final cacheDir = await _getCacheDir();
        final tempFile = File('${cacheDir.path}/$videoId.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    } finally {
      _activeDownloads.remove(videoId);
    }
  }

  void cancelDownload(String videoId) {
    final token = _activeDownloads.remove(videoId);
    if (token != null) {
      token.cancel();
      debugPrint('[MediaCacheService] Cancelled download for $videoId');
    }
  }

  Future<void> cleanOldCacheFiles(List<String> activeQueueVideoIds) async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync();
      final activeSet = activeQueueVideoIds.toSet();
      for (final entity in files) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final dotIndex = name.indexOf('.');
          if (dotIndex != -1) {
            final videoId = name.substring(0, dotIndex);
            if (!activeSet.contains(videoId)) {
              await entity.delete();
              debugPrint('[MediaCacheService] Cleaned up cached file: $name');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheService] cleanOldCacheFiles error: $e');
    }
  }
}
