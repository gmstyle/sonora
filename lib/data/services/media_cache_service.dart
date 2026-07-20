import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Service for caching audio files to disk for offline fallback and lookahead.
///
/// This cache is separate from the mpv native cache (configured in
/// `_initPlayerCache()`), which handles buffering of the currently playing
/// track. This service is responsible for:
/// - Pre-caching upcoming tracks in the queue (lookahead)
/// - Providing offline fallback when network connectivity is lost
///
/// The cache uses LRU (Least Recently Used) eviction with a configurable
/// size limit (default: 500MB). When the limit is exceeded, the oldest
/// files (by modification time) are automatically deleted.
class MediaCacheService {
  static final MediaCacheService instance = MediaCacheService._internal();
  MediaCacheService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};

  /// Maximum total size of the cache in bytes (default: 500MB).
  /// When exceeded, the least recently modified files are deleted.
  final int maxCacheSizeBytes = 500 * 1024 * 1024;

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
            // Touch the file to update its mtime (LRU tracking)
            await entity.setLastModified(DateTime.now());
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
        // Enforce size limit after successful download
        await _enforceSizeLimit();
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

  /// Enforces the cache size limit by deleting the oldest files (LRU eviction).
  Future<void> _enforceSizeLimit() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync().whereType<File>().toList();

      // Calculate total size and collect file info
      int totalSize = 0;
      final fileInfos = <_FileInfo>[];
      for (final file in files) {
        if (file.path.endsWith('.tmp')) continue; // Skip temp files
        final size = await file.length();
        totalSize += size;
        final mtime = await file.lastModified();
        fileInfos.add(_FileInfo(file, size, mtime));
      }

      // If under limit, nothing to do
      if (totalSize <= maxCacheSizeBytes) return;

      // Sort by mtime (oldest first) for LRU eviction
      fileInfos.sort((a, b) => a.mtime.compareTo(b.mtime));

      // Delete oldest files until under limit
      for (final info in fileInfos) {
        if (totalSize <= maxCacheSizeBytes) break;
        try {
          await info.file.delete();
          totalSize -= info.size;
          debugPrint(
            '[MediaCacheService] Evicted ${info.file.path.split('/').last} '
            '(${info.size} bytes, mtime: ${info.mtime})',
          );
        } catch (e) {
          debugPrint(
            '[MediaCacheService] Failed to evict ${info.file.path}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheService] _enforceSizeLimit error: $e');
    }
  }

  void cancelDownload(String videoId) {
    final token = _activeDownloads.remove(videoId);
    if (token != null) {
      token.cancel();
      debugPrint('[MediaCacheService] Cancelled download for $videoId');
    }
  }
}

class _FileInfo {
  final File file;
  final int size;
  final DateTime mtime;
  _FileInfo(this.file, this.size, this.mtime);
}
