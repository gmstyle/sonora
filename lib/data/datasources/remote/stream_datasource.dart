import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/utils/url_staleness.dart';
import '../../../domain/media/stream_quality_selector.dart';
import '../../../domain/models/media_quality.dart';
import 'youtube_request_scheduler.dart';

class StreamDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Shared gate for every outbound request this datasource makes to
  /// YouTube (manifest fetches for both playback and downloads). See
  /// [YoutubeRequestScheduler] for why a single global gate — rather than
  /// per-call timeouts scattered across the app — is the real fix for the
  /// classic YouTube Music 429 (rate limit) problem.
  final YoutubeRequestScheduler _scheduler;

  final StreamQualitySelector _selector;

  /// Default quality when callers omit [getStreamUrl]'s [quality] argument.
  /// Typically wired to the user's stream-quality setting.
  MediaQuality Function() getDefaultQuality;

  StreamDatasource({
    YoutubeRequestScheduler? scheduler,
    StreamQualitySelector? selector,
    MediaQuality Function()? getDefaultQuality,
  }) : _scheduler = scheduler ?? YoutubeRequestScheduler.shared,
       _selector = selector ?? const StreamQualitySelector(),
       getDefaultQuality = getDefaultQuality ?? (() => MediaQuality.high);

  /// In-memory cache: `videoId|quality|preferVideo` → resolved stream URL.
  ///
  /// Entries are validated with [UrlStaleness.isStale] before use, so stale
  /// YouTube URLs (which embed an `expire` timestamp) are never served.
  final Map<String, String> _urlCache = {};

  static String cacheKey(
    String videoId, {
    required MediaQuality quality,
    required bool preferVideo,
  }) => '$videoId|${quality.name}|$preferVideo';

  /// Resolves the stream URL for [videoId], serving from the in-memory cache
  /// when the cached URL is still valid.
  ///
  /// On [RequestLimitExceededException] (YouTube rate limiting), retries up to
  /// 3 times with exponential back-off (5 s → 15 s → 30 s) before re-throwing.
  /// Every underlying network attempt (including retries) also goes through
  /// [YoutubeRequestScheduler], which caps concurrency and enforces a minimum
  /// spacing between requests — the two together are what actually keep
  /// YouTube from rate-limiting the app in the first place, rather than just
  /// reacting to it after the fact.
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? quality,
    bool preferVideo = false,
    int attempt = 1,
  }) async {
    final resolvedQuality = quality ?? getDefaultQuality();
    final key = cacheKey(
      videoId,
      quality: resolvedQuality,
      preferVideo: preferVideo,
    );

    // Serve from cache if the URL has not yet expired.
    final cached = _urlCache[key];
    if (cached != null && !UrlStaleness.isStale(cached)) {
      return cached;
    }

    try {
      final manifest = await _scheduler.schedule(
        () => _yt.videos.streamsClient.getManifest(videoId),
      );
      final stream = _selector.select(
        manifest,
        quality: resolvedQuality,
        preferVideo: preferVideo,
      );
      final url = stream.url.toString();
      _urlCache[key] = url;
      return url;
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      // Exponential back-off: 5 s, 15 s before the 3rd (and last) attempt.
      // This sleep intentionally happens OUTSIDE the scheduler's slot (see
      // `getStreamUrl`'s retry not being wrapped in `schedule`) so a
      // rate-limited request backing off doesn't hold up the concurrency
      // budget for every other pending resolution.
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return getStreamUrl(
        videoId,
        quality: resolvedQuality,
        preferVideo: preferVideo,
        attempt: attempt + 1,
      );
    }
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _scheduler.schedule(() => _yt.videos.streamsClient.getManifest(videoId));

  /// Invalidates in-memory stream URL cache entries for [videoId]
  /// (all quality / preferVideo variants).
  void invalidateCache(String videoId) {
    _urlCache.removeWhere(
      (key, _) => key == videoId || key.startsWith('$videoId|'),
    );
  }

  /// Clears the entire in-memory URL cache (e.g. when stream quality changes).
  void clearUrlCache() {
    _urlCache.clear();
  }

  void dispose() {
    _yt.close();
  }
}
