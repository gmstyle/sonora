import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Service for caching media files to disk for offline fallback and lookahead.
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
///
/// Files may be audio-only (webm/mp3) or muxed video (mp4), depending on
/// whether video playback was preferred when the download started. Toggling
/// `enableVideoPlayback` clears this cache so a leftover audio file is not
/// reused as a video source (and vice versa).
class MediaCacheService {
  static final MediaCacheService instance = MediaCacheService._internal();
  MediaCacheService._internal();

  /// Directory name under the temp dir. Also used to detect cache URIs.
  static const cacheDirName = 'sonora_media_cache';

  /// Whether [url] points at a file in this service's temp cache (not a
  /// library download).
  static bool isMediaCacheUri(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('/$cacheDirName/') || url.contains('\\$cacheDirName\\');
  }

  /// Muxed video cache files use `.mp4`; audio-only uses `.webm` / `.mp3`.
  static bool isMuxedCacheUri(String? url) {
    if (!isMediaCacheUri(url)) return false;
    final lower = url!.toLowerCase();
    return lower.endsWith('.mp4');
  }

  /// Whether a media-cache URI is compatible with [preferVideo] playback.
  static bool isCacheCompatibleWithPreferVideo(String? url, bool preferVideo) {
    if (!isMediaCacheUri(url)) return false;
    return preferVideo ? isMuxedCacheUri(url) : !isMuxedCacheUri(url);
  }

  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};

  /// Maximum total size of the cache in bytes (default: 500MB).
  /// When exceeded, the least recently modified files are deleted.
  final int maxCacheSizeBytes = 500 * 1024 * 1024;

  /// videoIds of downloads currently in flight (snapshot copy).
  Set<String> get inFlightDownloads => _activeDownloads.keys.toSet();

  Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/$cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Returns a cached file URI for [videoId], or null.
  ///
  /// When [preferVideo] is true, only muxed `.mp4` files are returned so an
  /// leftover audio-only `.webm` cannot poison video playback. When false,
  /// prefers audio-only extensions (falls back to any match).
  Future<String?> getCachedFileUri(String videoId, {bool? preferVideo}) async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync().whereType<File>().toList();
      File? audioHit;
      File? muxedHit;
      File? anyHit;
      for (final entity in files) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.startsWith('$videoId.') || name.endsWith('.tmp')) continue;
        anyHit ??= entity;
        final lower = name.toLowerCase();
        if (lower.endsWith('.mp4')) {
          muxedHit = entity;
        } else if (lower.endsWith('.webm') || lower.endsWith('.mp3')) {
          audioHit = entity;
        }
      }
      final File? chosen;
      if (preferVideo == true) {
        chosen = muxedHit;
      } else if (preferVideo == false) {
        chosen = audioHit ?? anyHit;
      } else {
        chosen = anyHit;
      }
      if (chosen == null) return null;
      await chosen.setLastModified(DateTime.now());
      return chosen.uri.toString();
    } catch (e) {
      debugPrint('[MediaCacheService] getCachedFileUri error: $e');
    }
    return null;
  }

  Future<void> downloadToCache(String videoId, String streamUrl) async {
    if (_activeDownloads.containsKey(videoId)) return;
    final wantMuxed = _extensionForStreamUrl(streamUrl) == 'mp4';
    final existing = await getCachedFileUri(
      videoId,
      preferVideo: wantMuxed ? true : false,
    );
    if (existing != null) return;

    final cancelToken = CancelToken();
    _activeDownloads[videoId] = cancelToken;

    try {
      final cacheDir = await _getCacheDir();
      final ext = _extensionForStreamUrl(streamUrl);
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

  /// Infers a file extension from common YouTube stream MIME hints in [url].
  static String _extensionForStreamUrl(String url) {
    if (url.contains('mime=video%2Fmp4') || url.contains('mime=video/mp4')) {
      return 'mp4';
    }
    if (url.contains('mime=audio%2Fwebm') || url.contains('mime=audio/webm')) {
      return 'webm';
    }
    return 'mp3';
  }

  void cancelDownload(String videoId) {
    // Deliberately do NOT remove the entry from `_activeDownloads` here: the
    // download's own `finally` removes it after the cancellation settles, so
    // a fresh download for the same videoId cannot start while the old one is
    // still tearing down (the `containsKey` guard in `downloadToCache` keeps
    // protecting against duplicates in that window).
    final token = _activeDownloads[videoId];
    if (token != null) {
      token.cancel();
      debugPrint('[MediaCacheService] Cancelled download for $videoId');
    }
  }

  /// Deletes all cached media files and cancels in-flight downloads.
  /// Used when stream quality changes so stale quality files are not reused.
  Future<void> clearCache() async {
    for (final token in _activeDownloads.values) {
      token.cancel();
    }
    _activeDownloads.clear();
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            debugPrint(
              '[MediaCacheService] Failed to delete ${entity.path}: $e',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheService] clearCache error: $e');
    }
  }
}

class _FileInfo {
  final File file;
  final int size;
  final DateTime mtime;
  _FileInfo(this.file, this.size, this.mtime);
}
