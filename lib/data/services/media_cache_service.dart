import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Typed disk-cache hit (audio-only playback).
class MediaCacheHit {
  final String primaryUri;

  const MediaCacheHit({required this.primaryUri});
}

/// Service for caching audio files to disk for offline fallback and lookahead.
///
/// Playback always uses audio-only files. Muxed `{id}.mp4` and video-only
/// `{id}.v.*` leftovers from older builds are ignored for hits and evicted
/// with LRU (audio eviction also deletes a matching video sibling).
///
/// The cache uses LRU eviction with a configurable size limit (default: 1 GB).
class MediaCacheService {
  static final MediaCacheService instance = MediaCacheService._internal();
  MediaCacheService._internal();

  /// Directory name under the temp dir. Also used to detect cache URIs.
  static const cacheDirName = 'sonora_media_cache';

  /// Test-only cache directory (skips [getTemporaryDirectory]).
  @visibleForTesting
  Directory? debugCacheDir;

  /// Test-only size cap; when set, overrides [maxCacheSizeBytes].
  @visibleForTesting
  int? debugMaxCacheSizeBytes;

  /// Whether [url] points at a file in this service's temp cache (not a
  /// library download).
  static bool isMediaCacheUri(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('/$cacheDirName/') || url.contains('\\$cacheDirName\\');
  }

  /// Muxed video cache files use `{id}.mp4` — not `{id}.v.mp4`.
  static bool isMuxedCacheUri(String? url) {
    if (!isMediaCacheUri(url)) return false;
    return _isMuxedFileName(_fileNameOf(url!));
  }

  /// Video-only adaptive cache files: `{id}.v.{ext}`.
  static bool isVideoOnlyCacheUri(String? url) {
    if (!isMediaCacheUri(url)) return false;
    final name = _fileNameOf(url!);
    return !_isTempCacheFileName(name) && _isVideoOnlyFileName(name);
  }

  /// Audio-only cache files: `{id}.webm` / `{id}.mp3` (never `{id}.v.webm`).
  static bool isAudioOnlyCacheUri(String? url) {
    if (!isMediaCacheUri(url)) return false;
    final name = _fileNameOf(url!);
    return !_isTempCacheFileName(name) && _isAudioOnlyFileName(name);
  }

  /// True when [url] is an audio-only media-cache file the player may open.
  static bool isPlayableCacheUri(String? url) => isAudioOnlyCacheUri(url);

  final Map<String, CancelToken> _activeDownloads = {};

  /// Maximum total size of the cache in bytes (default: 1 GB).
  /// When exceeded, the least recently modified files are deleted.
  int maxCacheSizeBytes = 1024 * 1024 * 1024;

  int get _effectiveMaxCacheSizeBytes =>
      debugMaxCacheSizeBytes ?? maxCacheSizeBytes;

  /// Updates the LRU cap without scanning the cache directory.
  void applyMaxCacheSizeBytes(int bytes) {
    if (bytes <= 0) return;
    maxCacheSizeBytes = bytes;
  }

  /// Updates the LRU cap. If the new cap is below current usage, evicts
  /// oldest files (does not wipe the cache).
  Future<void> setMaxCacheSizeBytes(int bytes) async {
    applyMaxCacheSizeBytes(bytes);
    await _enforceSizeLimit();
  }

  /// videoIds of downloads currently in flight (snapshot copy).
  Set<String> get inFlightDownloads => _activeDownloads.keys.toSet();

  Future<Directory> _getCacheDir() async {
    if (debugCacheDir != null) {
      final cacheDir = debugCacheDir!;
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    }
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/$cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Audio-only cache lookup. Muxed / video-only leftovers are ignored.
  Future<MediaCacheHit?> getCachedHit(String videoId) async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync().whereType<File>().toList();
      File? audioHit;
      for (final entity in files) {
        final name = _fileNameOf(entity.path);
        if (!name.startsWith('$videoId.') || _isTempCacheFileName(name)) {
          continue;
        }
        if (_isAudioOnlyFileName(name)) {
          audioHit = entity;
          break;
        }
      }

      if (audioHit != null && await _isPoisonedPlaylistFile(audioHit)) {
        try {
          await audioHit.delete();
        } catch (_) {}
        audioHit = null;
      }
      if (audioHit == null) return null;

      final chosen = MediaCacheHit(primaryUri: audioHit.uri.toString());
      await _touchUri(chosen.primaryUri);
      return chosen;
    } catch (e) {
      debugPrint('[MediaCacheService] getCachedHit error: $e');
    }
    return null;
  }

  /// Returns a cached audio file URI for [videoId], or null.
  Future<String?> getCachedFileUri(String videoId) async {
    final hit = await getCachedHit(videoId);
    return hit?.primaryUri;
  }

  /// Writes an audio file into the cache via [write] (temp path + cancel token).
  ///
  /// [write] must use an authenticated downloader (youtube_explode
  /// [StreamClient]), not a raw GET of a googlevideo URL.
  Future<void> downloadAudioToCache({
    required String videoId,
    required String extension,
    required Future<void> Function(String tempPath, CancelToken cancelToken)
    write,
  }) async {
    if (_activeDownloads.containsKey(videoId)) return;
    final existing = await getCachedFileUri(videoId);
    if (existing != null) return;

    final cancelToken = CancelToken();
    _activeDownloads[videoId] = cancelToken;

    try {
      final cacheDir = await _getCacheDir();
      final ext = _sanitizeAudioExt(extension);
      final tempFilePath = '${cacheDir.path}/$videoId.tmp';
      final finalFilePath = '${cacheDir.path}/$videoId.$ext';

      debugPrint('[MediaCacheService] Starting cache download for $videoId...');
      await write(tempFilePath, cancelToken);

      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.rename(finalFilePath);
        debugPrint('[MediaCacheService] Cache download complete for $videoId');
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
  ///
  /// Pair rules: evicting audio-only also deletes the `{id}.v.*` sibling so a
  /// silent video file cannot remain. Evicting `{id}.v.*` leaves the audio.
  /// Muxed `{id}.mp4` is evicted alone.
  Future<void> _enforceSizeLimit() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync().whereType<File>().toList();

      int totalSize = 0;
      final fileInfos = <_FileInfo>[];
      for (final file in files) {
        final name = _fileNameOf(file.path);
        if (_isTempCacheFileName(name)) continue;
        final size = await file.length();
        totalSize += size;
        final mtime = await file.lastModified();
        fileInfos.add(_FileInfo(file, size, mtime, name));
      }

      if (totalSize <= _effectiveMaxCacheSizeBytes) return;

      fileInfos.sort((a, b) => a.mtime.compareTo(b.mtime));

      for (final info in fileInfos) {
        if (totalSize <= _effectiveMaxCacheSizeBytes) break;
        if (!await info.file.exists()) continue;
        try {
          await info.file.delete();
          totalSize -= info.size;
          debugPrint(
            '[MediaCacheService] Evicted ${_fileNameOf(info.file.path)} '
            '(${info.size} bytes, mtime: ${info.mtime})',
          );
        } catch (e) {
          debugPrint(
            '[MediaCacheService] Failed to evict ${info.file.path}: $e',
          );
          continue;
        }

        if (_isAudioOnlyFileName(info.name)) {
          final id = _videoIdFromCacheFileName(info.name);
          if (id == null) continue;
          for (final other in fileInfos) {
            if (identical(other, info)) continue;
            if (_videoIdFromCacheFileName(other.name) != id) continue;
            if (!_isVideoOnlyFileName(other.name)) continue;
            if (!await other.file.exists()) continue;
            try {
              await other.file.delete();
              totalSize -= other.size;
              debugPrint(
                '[MediaCacheService] Evicted sibling '
                '${_fileNameOf(other.file.path)} with audio $id',
              );
            } catch (e) {
              debugPrint(
                '[MediaCacheService] Failed to evict sibling '
                '${other.file.path}: $e',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCacheService] _enforceSizeLimit error: $e');
    }
  }

  @visibleForTesting
  Future<void> debugEnforceSizeLimit() => _enforceSizeLimit();

  static String _sanitizeAudioExt(String ext) {
    final lower = ext.toLowerCase();
    if (lower.contains('webm')) return 'webm';
    return 'mp3';
  }

  /// YouTube HLS master/media playlist URLs (not progressive media).
  static bool isHlsPlaylistUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/api/manifest/hls') ||
        lower.contains('.m3u8') ||
        lower.contains('mpegurl');
  }

  static Future<bool> _isPoisonedPlaylistFile(File file) async {
    try {
      final length = await file.length();
      if (length == 0 || length > 256 * 1024) return false;
      final header = await file.openRead(0, math.min(16, length)).first;
      final text = String.fromCharCodes(header);
      return text.startsWith('#EXTM3U') || text.startsWith('#EXT-X-');
    } catch (_) {
      return false;
    }
  }

  void cancelDownload(String videoId) {
    // Deliberately do NOT remove the entry from `_activeDownloads` here: the
    // download's own `finally` removes it after the cancellation settles, so
    // a fresh download for the same videoId cannot start while the old one is
    // still tearing down (the `containsKey` guard in `downloadAudioToCache`
    // keeps protecting against duplicates in that window).
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

  static Future<void> _touchUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      await File.fromUri(uri).setLastModified(DateTime.now());
    } catch (_) {}
  }

  static String _fileNameOf(String pathOrUrl) {
    final normalized = pathOrUrl.replaceAll('\\', '/');
    final withoutQuery = normalized.split('?').first;
    return withoutQuery.split('/').last;
  }

  static bool _isTempCacheFileName(String name) {
    return name.endsWith('.tmp') || name.contains('.tmp.');
  }

  /// `{id}.v.{ext}` — the token after the first dot starts with `v.`.
  static bool _isVideoOnlyFileName(String name) {
    final lower = name.toLowerCase();
    final dot = lower.indexOf('.');
    if (dot <= 0) return false;
    return lower.substring(dot + 1).startsWith('v.');
  }

  static bool _isMuxedFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') && !_isVideoOnlyFileName(name);
  }

  static bool _isAudioOnlyFileName(String name) {
    if (_isVideoOnlyFileName(name)) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.webm') || lower.endsWith('.mp3');
  }

  static String? _videoIdFromCacheFileName(String name) {
    final base = _fileNameOf(name);
    final dot = base.indexOf('.');
    if (dot <= 0) return null;
    return base.substring(0, dot);
  }
}

class _FileInfo {
  final File file;
  final int size;
  final DateTime mtime;
  final String name;
  _FileInfo(this.file, this.size, this.mtime, this.name);
}
