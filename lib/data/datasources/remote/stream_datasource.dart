import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/utils/url_staleness.dart';
import '../../../domain/media/stream_quality_selector.dart';
import '../../../domain/models/media_quality.dart';
import '../../services/media_cache_service.dart';
import 'youtube_request_scheduler.dart';

/// Cached URL for one videoId + audio quality combination.
class PlaybackUrlPlan {
  final String primaryUrl;

  const PlaybackUrlPlan({required this.primaryUrl});

  bool get isStale => UrlStaleness.isStale(primaryUrl);
}

class StreamDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Shared gate for every outbound request this datasource makes to
  /// YouTube (manifest fetches for both playback and downloads). See
  /// [YoutubeRequestScheduler] for why a single global gate — rather than
  /// per-call timeouts scattered across the app — is the real fix for the
  /// classic YouTube Music 429 (rate limit) problem.
  final YoutubeRequestScheduler _scheduler;

  final StreamQualitySelector _selector;

  /// Default audio tier when callers omit [audioQuality].
  MediaQuality Function() getDefaultAudioQuality;

  StreamDatasource({
    YoutubeRequestScheduler? scheduler,
    StreamQualitySelector? selector,
    MediaQuality Function()? getDefaultAudioQuality,
    @Deprecated('Use getDefaultAudioQuality')
    MediaQuality Function()? getDefaultQuality,
  }) : _scheduler = scheduler ?? YoutubeRequestScheduler.shared,
       _selector = selector ?? const StreamQualitySelector(),
       getDefaultAudioQuality =
           getDefaultAudioQuality ??
           getDefaultQuality ??
           (() => MediaQuality.high);

  /// In-memory playback plans: `videoId|audioQ` → URL.
  final Map<String, PlaybackUrlPlan> _playbackCache = {};

  static String playbackKey(
    String videoId, {
    required MediaQuality audioQuality,
  }) => '$videoId|${audioQuality.name}';

  /// Ensures a stream URL is resolved and cached for [videoId].
  Future<PlaybackUrlPlan> ensurePlaybackSelection(
    String videoId, {
    MediaQuality? audioQuality,
    int attempt = 1,
  }) async {
    final resolvedAudio = audioQuality ?? getDefaultAudioQuality();
    final key = playbackKey(videoId, audioQuality: resolvedAudio);

    final cached = _playbackCache[key];
    if (cached != null && !cached.isStale) {
      return cached;
    }

    try {
      final manifest = await _scheduler.schedule(
        () => _yt.videos.streamsClient.getManifest(videoId),
      );
      final selection = _selector.select(manifest, quality: resolvedAudio);
      final primaryUrl = selection.url.toString();
      _assertAbsoluteHttpUrl(primaryUrl, 'primary');
      final plan = PlaybackUrlPlan(primaryUrl: primaryUrl);
      _playbackCache[key] = plan;
      return plan;
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return ensurePlaybackSelection(
        videoId,
        audioQuality: resolvedAudio,
        attempt: attempt + 1,
      );
    } on ArgumentError catch (_) {
      // youtube_explode can surface "No host specified in URI" when a
      // transient empty stream URL slips through; one retry usually recovers.
      if (attempt >= 2) rethrow;
      await Future.delayed(const Duration(milliseconds: 400));
      return ensurePlaybackSelection(
        videoId,
        audioQuality: resolvedAudio,
        attempt: attempt + 1,
      );
    }
  }

  static void _assertAbsoluteHttpUrl(String url, String label) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError('Invalid $label stream URL (no host): "$url"');
    }
  }

  /// Resolves the stream URL for [videoId], serving from the in-memory cache
  /// when the cached URL is still valid.
  ///
  /// On [RequestLimitExceededException] (YouTube rate limiting), retries up to
  /// 3 times with exponential back-off (5 s → 15 s → 30 s) before re-throwing.
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? audioQuality,
    int attempt = 1,
  }) async {
    final resolvedAudio = audioQuality ?? getDefaultAudioQuality();

    try {
      final plan = await ensurePlaybackSelection(
        videoId,
        audioQuality: resolvedAudio,
      );
      return plan.primaryUrl;
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return getStreamUrl(
        videoId,
        audioQuality: resolvedAudio,
        attempt: attempt + 1,
      );
    }
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _scheduler.schedule(() => _yt.videos.streamsClient.getManifest(videoId));

  /// Writes [stream] to [filePath] using youtube_explode's HTTP client.
  ///
  /// A raw GET of [StreamInfo.url] (e.g. via Dio) is often rejected with 403
  /// after the same URL has been probed or played. [StreamClient.get] sends
  /// the headers/cookies the CDN expects and concatenates HLS fragments.
  Future<void> downloadStreamToFile(
    StreamInfo stream,
    String filePath, {
    CancelToken? cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: filePath),
        type: DioExceptionType.cancel,
      );
    }

    final sink = File(filePath).openWrite();
    StreamSubscription<List<int>>? sub;
    final done = Completer<void>();
    var received = 0;
    final total = stream.size.totalBytes;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (!done.isCompleted) {
        done.completeError(error, stackTrace);
      }
    }

    try {
      sub = _yt.videos.streamsClient
          .get(stream)
          .listen(
            (chunk) {
              sink.add(chunk);
              received += chunk.length;
              if (total > 0) onProgress(received, total);
            },
            onError: fail,
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );

      if (cancelToken != null) {
        unawaited(
          cancelToken.whenCancel.then((_) async {
            await sub?.cancel();
            fail(
              DioException(
                requestOptions: RequestOptions(path: filePath),
                type: DioExceptionType.cancel,
              ),
            );
          }),
        );
      }

      await done.future;
    } finally {
      await sub?.cancel();
      await sink.close();
    }
  }

  /// Downloads the audio stream for [videoId] into [MediaCacheService] using
  /// the same authenticated [StreamClient] as library downloads.
  ///
  /// Failures are logged and swallowed so lookahead / background cache never
  /// interrupts playback.
  Future<void> cacheAudio(
    String videoId, {
    MediaQuality? audioQuality,
  }) async {
    try {
      final cache = MediaCacheService.instance;
      if (await cache.getCachedFileUri(videoId) != null) return;

      final resolvedAudio = audioQuality ?? getDefaultAudioQuality();
      final manifest = await getManifest(videoId);
      final stream = _selector.select(manifest, quality: resolvedAudio);
      await cache.downloadAudioToCache(
        videoId: videoId,
        extension: stream.container.name,
        write: (tempPath, token) => downloadStreamToFile(
          stream,
          tempPath,
          cancelToken: token,
          onProgress: (_, __) {},
        ),
      );
    } catch (e) {
      dev.log('[StreamDatasource] cacheAudio failed for $videoId: $e');
    }
  }

  /// Invalidates in-memory stream URL cache entries for [videoId]
  /// (all quality variants).
  void invalidateCache(String videoId) {
    _playbackCache.removeWhere(
      (key, _) => key == videoId || key.startsWith('$videoId|'),
    );
  }

  /// Clears the entire in-memory URL cache (e.g. when stream quality changes).
  void clearUrlCache() {
    _playbackCache.clear();
  }

  void dispose() {
    _yt.close();
  }
}
