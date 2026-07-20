import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/utils/url_staleness.dart';
import 'youtube_request_scheduler.dart';

class StreamDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Shared gate for every outbound request this datasource makes to
  /// YouTube (manifest fetches for both playback and downloads). See
  /// [YoutubeRequestScheduler] for why a single global gate — rather than
  /// per-call timeouts scattered across the app — is the real fix for the
  /// classic YouTube Music 429 (rate limit) problem.
  final YoutubeRequestScheduler _scheduler;

  StreamDatasource({YoutubeRequestScheduler? scheduler})
    : _scheduler = scheduler ?? YoutubeRequestScheduler.shared;

  /// In-memory cache: videoId → resolved stream URL.
  ///
  /// Entries are validated with [UrlStaleness.isStale] before use, so stale
  /// YouTube URLs (which embed an `expire` timestamp) are never served.
  final Map<String, String> _urlCache = {};

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
  Future<String> getStreamUrl(String videoId, {int attempt = 1}) async {
    // Serve from cache if the URL has not yet expired.
    final cached = _urlCache[videoId];
    if (cached != null && !UrlStaleness.isStale(cached)) {
      return cached;
    }

    try {
      final manifest = await _scheduler.schedule(
        () => _yt.videos.streamsClient.getManifest(videoId),
      );
      // uso muxed e non audioOnly per bug youtube_explode_dart
      // https://github.com/Hexer10/youtube_explode_dart/issues/332
      final url = manifest.muxed.withHighestBitrate().url.toString();
      _urlCache[videoId] = url;
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
      return getStreamUrl(videoId, attempt: attempt + 1);
    }
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _scheduler.schedule(() => _yt.videos.streamsClient.getManifest(videoId));

  void dispose() {
    _yt.close();
  }
}
