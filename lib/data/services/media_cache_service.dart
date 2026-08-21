import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Typed disk-cache hit: audio-only, muxed A+V, or a complete adaptive pair.
class MediaCacheHit {
  /// File to play as the primary media URI (audio, muxed, or video-only).
  final String primaryUri;

  /// Sibling audio for a video-only pair; null for audio-only and muxed hits.
  final String? externalAudioUri;

  const MediaCacheHit({required this.primaryUri, this.externalAudioUri});

  bool get isPair => externalAudioUri != null;
}

/// Service for caching media files to disk for offline fallback and lookahead.
///
/// This cache is separate from the mpv native cache (configured in
/// `_initPlayerCache()`), which handles buffering of the currently playing
/// track. This service is responsible for:
/// - Pre-caching upcoming tracks in the queue (lookahead)
/// - Providing offline fallback when network connectivity is lost
///
/// The cache uses LRU (Least Recently Used) eviction with a configurable
/// size limit (default: 1 GB, user-configurable). When the limit is exceeded, the oldest
/// files (by modification time) are automatically deleted.
///
/// Layout under [cacheDirName]:
/// - `{videoId}.webm` / `{videoId}.mp3` — audio-only (shared by audio
///   playback and adaptive video pairs)
/// - `{videoId}.mp4` — muxed A+V (progressive YouTube or legacy remux)
/// - `{videoId}.v.{ext}` — video-only; never treated as muxed
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

  /// Whether a media-cache URI is compatible with [preferVideo] playback.
  ///
  /// Video requires muxed **or** a complete pair (video-only + sibling audio).
  /// Audio requires audio-only — never muxed or silent video-only.
  static bool isCacheCompatibleWithPreferVideo(String? url, bool preferVideo) {
    if (!isMediaCacheUri(url)) return false;
    if (!preferVideo) return isAudioOnlyCacheUri(url);
    if (isMuxedCacheUri(url)) return true;
    if (isVideoOnlyCacheUri(url)) {
      return siblingAudioUriIfExists(url) != null;
    }
    return false;
  }

  /// Sibling `{id}.webm` / `{id}.mp3` next to a video-only cache URI, if present.
  static String? siblingAudioUriIfExists(String? videoOnlyUrl) {
    if (!isVideoOnlyCacheUri(videoOnlyUrl)) return null;
    final uri = Uri.tryParse(videoOnlyUrl!);
    if (uri == null || !uri.isScheme('file')) return null;
    final file = File.fromUri(uri);
    final id = _videoIdFromCacheFileName(_fileNameOf(file.path));
    if (id == null) return null;
    final dir = file.parent;
    for (final ext in const ['webm', 'mp3']) {
      final sibling = File('${dir.path}${Platform.pathSeparator}$id.$ext');
      if (sibling.existsSync() &&
          _isAudioOnlyFileName(_fileNameOf(sibling.path))) {
        return sibling.uri.toString();
      }
    }
    return null;
  }

  final Dio _dio = Dio();
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

  /// Typed cache lookup. See [MediaCacheHit].
  ///
  /// - [preferVideo] `false` → audio-only or `null` (never muxed / video-only)
  /// - [preferVideo] `true` → muxed `{id}.mp4`, or a complete `{id}.v.*` +
  ///   audio-only pair; incomplete pairs are a miss
  /// - [preferVideo] `null` → audio-only, else muxed, else complete pair
  Future<MediaCacheHit?> getCachedHit(
    String videoId, {
    bool? preferVideo,
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final files = cacheDir.listSync().whereType<File>().toList();
      File? audioHit;
      File? muxedHit;
      File? videoOnlyHit;
      for (final entity in files) {
        final name = _fileNameOf(entity.path);
        if (!name.startsWith('$videoId.') || _isTempCacheFileName(name)) {
          continue;
        }
        if (_isVideoOnlyFileName(name)) {
          videoOnlyHit ??= entity;
        } else if (_isMuxedFileName(name)) {
          muxedHit ??= entity;
        } else if (_isAudioOnlyFileName(name)) {
          audioHit ??= entity;
        }
      }

      Future<File?> dropIfPoisoned(File? file) async {
        if (file == null) return null;
        if (await _isPoisonedPlaylistFile(file)) {
          try {
            await file.delete();
          } catch (_) {}
          return null;
        }
        return file;
      }

      audioHit = await dropIfPoisoned(audioHit);
      muxedHit = await dropIfPoisoned(muxedHit);
      videoOnlyHit = await dropIfPoisoned(videoOnlyHit);

      final audio = audioHit;
      final muxed = muxedHit;
      final videoOnly = videoOnlyHit;

      MediaCacheHit? audioResult() =>
          audio == null
              ? null
              : MediaCacheHit(primaryUri: audio.uri.toString());
      MediaCacheHit? muxedResult() =>
          muxed == null
              ? null
              : MediaCacheHit(primaryUri: muxed.uri.toString());
      MediaCacheHit? pairResult() {
        if (videoOnly == null || audio == null) return null;
        return MediaCacheHit(
          primaryUri: videoOnly.uri.toString(),
          externalAudioUri: audio.uri.toString(),
        );
      }

      final MediaCacheHit? chosen;
      if (preferVideo == true) {
        chosen = muxedResult() ?? pairResult();
      } else if (preferVideo == false) {
        chosen = audioResult();
      } else {
        chosen = audioResult() ?? muxedResult() ?? pairResult();
      }
      if (chosen == null) return null;

      await _touchUri(chosen.primaryUri);
      if (chosen.externalAudioUri != null) {
        await _touchUri(chosen.externalAudioUri!);
      }
      return chosen;
    } catch (e) {
      debugPrint('[MediaCacheService] getCachedHit error: $e');
    }
    return null;
  }

  /// Returns a cached file URI for [videoId], or null.
  ///
  /// When [preferVideo] is true, only muxed `{id}.mp4` is returned so the
  /// HTTP proxy never serves silent video-only. Use [getCachedHit] when a
  /// complete adaptive pair should be reused for playback.
  /// When false, only audio-only `.webm`/`.mp3` are returned.
  Future<String?> getCachedFileUri(String videoId, {bool? preferVideo}) async {
    final hit = await getCachedHit(videoId, preferVideo: preferVideo);
    if (hit == null) return null;
    if (preferVideo == true && hit.isPair) return null;
    return hit.primaryUri;
  }

  Future<void> downloadToCache(String videoId, String streamUrl) async {
    if (_activeDownloads.containsKey(videoId)) return;
    // HLS master/media playlists are tiny text manifests with expiring
    // segment URLs — caching them poisons the media cache and breaks
    // subsequent "offline" / cache-hit playback.
    if (_isHlsPlaylistUrl(streamUrl)) return;
    final wantMuxed = _extensionForStreamUrl(streamUrl) == 'mp4';
    if (wantMuxed) {
      final existing = await getCachedHit(videoId, preferVideo: true);
      if (existing != null) return;
    } else {
      final existing = await getCachedFileUri(videoId, preferVideo: false);
      if (existing != null) return;
    }

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

  /// Downloads adaptive video-only + audio-only URLs as a dual-file pair:
  /// `{videoId}.v.{ext}` + `{videoId}.{audioExt}`.
  ///
  /// Reuses an existing audio-only cache from a previous listen. Shares
  /// [_activeDownloads] with [downloadToCache] so the two cannot race.
  Future<void> downloadAdaptivePair({
    required String videoId,
    required String videoUrl,
    required String audioUrl,
    required String videoExt,
    required String audioExt,
  }) async {
    if (_activeDownloads.containsKey(videoId)) return;
    final existing = await getCachedHit(videoId, preferVideo: true);
    if (existing != null) return;

    final cancelToken = CancelToken();
    _activeDownloads[videoId] = cancelToken;

    final cacheDir = await _getCacheDir();
    final vExt = _sanitizeVideoExt(videoExt);
    final aExt = _sanitizeAudioExt(audioExt);
    final videoTmp = File('${cacheDir.path}/$videoId.v.tmp.$vExt');
    final audioTmp = File('${cacheDir.path}/$videoId.a.tmp.$aExt');
    final videoFinal = File('${cacheDir.path}/$videoId.v.$vExt');
    final audioFinal = File('${cacheDir.path}/$videoId.$aExt');

    final hasAudio = _findAudioOnly(cacheDir, videoId) != null;
    final hasVideo = _findVideoOnly(cacheDir, videoId) != null;

    try {
      debugPrint(
        '[MediaCacheService] Starting adaptive pair cache for $videoId...',
      );
      final downloads = <Future<void>>[];
      if (!hasVideo) {
        downloads.add(
          _dio.download(videoUrl, videoTmp.path, cancelToken: cancelToken),
        );
      }
      if (!hasAudio) {
        downloads.add(
          _dio.download(audioUrl, audioTmp.path, cancelToken: cancelToken),
        );
      }
      if (downloads.isEmpty) return;
      await Future.wait(downloads);

      if (cancelToken.isCancelled) return;

      if (!hasVideo && await videoTmp.exists()) {
        if (await videoFinal.exists()) await videoFinal.delete();
        await videoTmp.rename(videoFinal.path);
      }
      if (!hasAudio && await audioTmp.exists()) {
        if (await audioFinal.exists()) await audioFinal.delete();
        await audioTmp.rename(audioFinal.path);
      }
      debugPrint(
        '[MediaCacheService] Cache download complete for $videoId (adaptive pair)',
      );
      await _enforceSizeLimit();
    } catch (e) {
      debugPrint(
        '[MediaCacheService] Adaptive pair cache failed for $videoId: $e',
      );
    } finally {
      for (final f in [videoTmp, audioTmp]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
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

  static String _sanitizeVideoExt(String ext) {
    final lower = ext.toLowerCase();
    if (lower.contains('webm')) return 'webm';
    return 'mp4';
  }

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

  /// YouTube HLS master/media playlist URLs (not progressive media).
  static bool _isHlsPlaylistUrl(String url) => isHlsPlaylistUrl(url);

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

  static File? _findAudioOnly(Directory cacheDir, String videoId) {
    for (final ext in const ['webm', 'mp3']) {
      final file = File(
        '${cacheDir.path}${Platform.pathSeparator}$videoId.$ext',
      );
      if (file.existsSync() && _isAudioOnlyFileName(_fileNameOf(file.path))) {
        return file;
      }
    }
    return null;
  }

  static File? _findVideoOnly(Directory cacheDir, String videoId) {
    try {
      for (final entity in cacheDir.listSync().whereType<File>()) {
        final name = _fileNameOf(entity.path);
        if (_isTempCacheFileName(name)) continue;
        if (name.startsWith('$videoId.') && _isVideoOnlyFileName(name)) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }
}

class _FileInfo {
  final File file;
  final int size;
  final DateTime mtime;
  final String name;
  _FileInfo(this.file, this.size, this.mtime, this.name);
}
