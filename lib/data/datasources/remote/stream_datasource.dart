import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/utils/url_staleness.dart';
import '../../../domain/media/stream_quality_selector.dart';
import '../../../domain/models/media_quality.dart';
import '../../../domain/models/stream_role.dart';
import 'youtube_request_scheduler.dart';

/// Cached URLs for one videoId + audio/video quality + preferVideo combination.
class PlaybackUrlPlan {
  final String primaryUrl;
  final String? externalAudioUrl;

  const PlaybackUrlPlan({required this.primaryUrl, this.externalAudioUrl});

  bool get isAdaptive => externalAudioUrl != null;

  bool get isStale =>
      UrlStaleness.isStale(primaryUrl) ||
      (externalAudioUrl != null && UrlStaleness.isStale(externalAudioUrl!));
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

  /// Default video tier when callers omit [videoQuality].
  MediaQuality Function() getDefaultVideoQuality;

  StreamDatasource({
    YoutubeRequestScheduler? scheduler,
    StreamQualitySelector? selector,
    MediaQuality Function()? getDefaultAudioQuality,
    MediaQuality Function()? getDefaultVideoQuality,
    @Deprecated('Use getDefaultAudioQuality')
    MediaQuality Function()? getDefaultQuality,
  }) : _scheduler = scheduler ?? YoutubeRequestScheduler.shared,
       _selector = selector ?? const StreamQualitySelector(),
       getDefaultAudioQuality =
           getDefaultAudioQuality ??
           getDefaultQuality ??
           (() => MediaQuality.high),
       getDefaultVideoQuality =
           getDefaultVideoQuality ??
           getDefaultQuality ??
           (() => MediaQuality.high);

  /// In-memory playback plans: `videoId|audioQ|videoQ|preferVideo` → URLs.
  final Map<String, PlaybackUrlPlan> _playbackCache = {};

  static String playbackKey(
    String videoId, {
    required MediaQuality audioQuality,
    required MediaQuality videoQuality,
    required bool preferVideo,
  }) => '$videoId|${audioQuality.name}|${videoQuality.name}|$preferVideo';

  /// Ensures stream URLs are resolved and cached for [videoId].
  ///
  /// One manifest fetch populates primary (+ external audio when adaptive).
  Future<PlaybackUrlPlan> ensurePlaybackSelection(
    String videoId, {
    MediaQuality? audioQuality,
    MediaQuality? videoQuality,
    bool preferVideo = false,
    int attempt = 1,
  }) async {
    final resolvedAudio = audioQuality ?? getDefaultAudioQuality();
    final resolvedVideo = videoQuality ?? getDefaultVideoQuality();
    final key = playbackKey(
      videoId,
      audioQuality: resolvedAudio,
      videoQuality: resolvedVideo,
      preferVideo: preferVideo,
    );

    final cached = _playbackCache[key];
    if (cached != null && !cached.isStale) {
      return cached;
    }

    try {
      final manifest = await _scheduler.schedule(
        () => _yt.videos.streamsClient.getManifest(videoId),
      );
      final selection = _selector.selectPlayback(
        manifest,
        audioQuality: resolvedAudio,
        videoQuality: resolvedVideo,
        preferVideo: preferVideo,
      );
      final primaryUrl = selection.primary.url.toString();
      final externalAudioUrl = selection.externalAudio?.url.toString();
      _assertAbsoluteHttpUrl(primaryUrl, 'primary');
      if (externalAudioUrl != null) {
        _assertAbsoluteHttpUrl(externalAudioUrl, 'externalAudio');
      }
      final plan = PlaybackUrlPlan(
        primaryUrl: primaryUrl,
        externalAudioUrl: externalAudioUrl,
      );
      _playbackCache[key] = plan;
      return plan;
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return ensurePlaybackSelection(
        videoId,
        audioQuality: resolvedAudio,
        videoQuality: resolvedVideo,
        preferVideo: preferVideo,
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
        videoQuality: resolvedVideo,
        preferVideo: preferVideo,
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
    MediaQuality? videoQuality,
    bool preferVideo = false,
    StreamRole role = StreamRole.primary,
    int attempt = 1,
  }) async {
    final resolvedAudio = audioQuality ?? getDefaultAudioQuality();
    final resolvedVideo = videoQuality ?? getDefaultVideoQuality();

    try {
      final plan = await ensurePlaybackSelection(
        videoId,
        audioQuality: resolvedAudio,
        videoQuality: resolvedVideo,
        preferVideo: preferVideo,
      );

      switch (role) {
        case StreamRole.primary:
        case StreamRole.video:
          return plan.primaryUrl;
        case StreamRole.audio:
          if (plan.externalAudioUrl != null) {
            return plan.externalAudioUrl!;
          }
          // Non-adaptive preferVideo still may request kind=audio; serve
          // a dedicated audio-only URL without attaching it in the binder.
          final audioPlan = await ensurePlaybackSelection(
            videoId,
            audioQuality: resolvedAudio,
            videoQuality: resolvedVideo,
            preferVideo: false,
          );
          return audioPlan.primaryUrl;
      }
    } on RequestLimitExceededException {
      if (attempt >= 3) rethrow;
      final delaySeconds = attempt == 1 ? 5 : 15;
      await Future.delayed(Duration(seconds: delaySeconds));
      return getStreamUrl(
        videoId,
        audioQuality: resolvedAudio,
        videoQuality: resolvedVideo,
        preferVideo: preferVideo,
        role: role,
        attempt: attempt + 1,
      );
    }
  }

  Future<StreamManifest> getManifest(String videoId) =>
      _scheduler.schedule(() => _yt.videos.streamsClient.getManifest(videoId));

  /// Invalidates in-memory stream URL cache entries for [videoId]
  /// (all quality / preferVideo variants).
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
