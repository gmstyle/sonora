import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/utils/url_staleness.dart';

class StreamDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

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
  Future<String> getStreamUrl(String videoId, {int attempt = 1}) async {
    // Serve from cache if the URL has not yet expired.
    final cached = _urlCache[videoId];
    if (cached != null && !UrlStaleness.isStale(cached)) {
      return cached;
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // uso muxed e non audioOnly per bug youtube_explode_dart
      // https://github.com/Hexer10/youtube_explode_dart/issues/332
      final url = manifest.muxed.withHighestBitrate().url.toString();
      _urlCache[videoId] = url;
      return url;
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      // Exponential back-off: 5 s, 15 s before the 3rd (and last) attempt.
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return getStreamUrl(videoId, attempt: attempt + 1);
    }
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _yt.videos.streamsClient.getManifest(videoId);

  void dispose() {
    _yt.close();
  }
}
