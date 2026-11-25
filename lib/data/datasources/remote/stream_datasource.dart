import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart' as ytm;
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/js_challenge.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/errors/youtube_rate_limited_exception.dart';
import '../../../core/utils/url_staleness.dart';
import '../../../domain/media/stream_quality_selector.dart';
import '../../../domain/models/media_quality.dart';
import '../../services/media_cache_service.dart';
import 'youtube_request_scheduler.dart';
import 'ytm_session_http_client.dart';

/// Cached stream selection for one videoId + audio quality combination.
class PlaybackUrlPlan {
  final String primaryUrl;
  final SabrAudioStreamInfo? sabrStream;

  const PlaybackUrlPlan({required this.primaryUrl, this.sabrStream});

  bool get isSabr => sabrStream != null;

  bool get isStale => UrlStaleness.isStale(primaryUrl);
}

class StreamDatasource {
  final YoutubeExplode _yt;
  final BasePoTokenProvider? _poTokenProvider;
  final Future<bool> Function() _isSignedIn;
  final void Function()? _onDispose;

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
    YoutubeExplode? youtubeExplode,
    YoutubeHttpClient? httpClient,
    BaseJSChallengeSolver? jsSolver,
    BasePoTokenProvider? poTokenProvider,
    Future<bool> Function()? isSignedIn,
    this._onDispose,
    YoutubeRequestScheduler? scheduler,
    StreamQualitySelector? selector,
    MediaQuality Function()? getDefaultAudioQuality,
    @Deprecated('Use getDefaultAudioQuality')
    MediaQuality Function()? getDefaultQuality,
  }) : _poTokenProvider = poTokenProvider,
       _isSignedIn =
           isSignedIn ?? (() => ytm.isSignedIn(ytm.YTMusic().cookieJar)),
       _yt =
           youtubeExplode ??
           YoutubeExplode(
             httpClient:
                 httpClient ?? YoutubeHttpClient(YtmSessionHttpClient()),
             jsSolver: jsSolver,
             poTokenProvider: poTokenProvider,
           ),
       _scheduler = scheduler ?? YoutubeRequestScheduler.shared,
       _selector = selector ?? const StreamQualitySelector(),
       getDefaultAudioQuality =
           getDefaultAudioQuality ??
           getDefaultQuality ??
           (() => MediaQuality.high);

  /// In-memory playback plans: `videoId|audioQ` → URL.
  final Map<String, PlaybackUrlPlan> _playbackCache = {};

  /// True while the shared scheduler is in a post-429 cool-down.
  bool get isRateLimited => _scheduler.isCoolingDown;

  /// Remaining cool-down, or `null` when stream resolution is allowed.
  Duration? get rateLimitRetryAfter => _scheduler.coolDownRemaining;

  /// Opens the cool-down without waiting for the next manifest call
  /// (e.g. CDN HTTP 429 observed by the local audio proxy).
  void reportRateLimit([Duration? duration]) =>
      _scheduler.enterCoolDown(duration);

  static String playbackKey(
    String videoId, {
    required MediaQuality audioQuality,
  }) => '$videoId|${audioQuality.name}';

  /// Ensures a stream URL is resolved and cached for [videoId].
  ///
  /// Does **not** retry HTTP 429: a rate-limit trips the scheduler cool-down
  /// and further calls fail fast with [YoutubeRateLimitedException].
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
      final manifest = await _fetchManifest(videoId);
      final selection = _selector.select(manifest, quality: resolvedAudio);
      final primaryUrl = selection.url.toString();
      _assertAbsoluteHttpUrl(primaryUrl, 'primary');
      final plan = PlaybackUrlPlan(
        primaryUrl: primaryUrl,
        sabrStream: selection is SabrAudioStreamInfo ? selection : null,
      );
      _playbackCache[key] = plan;
      return plan;
    } on YoutubeRateLimitedException {
      rethrow;
    } on RequestLimitExceededException {
      _scheduler.enterCoolDown();
      rethrow;
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

  Future<StreamManifest> _fetchManifest(String videoId) {
    return _scheduler.schedule(() async {
      final signedIn = await _isSignedIn();
      final hasPoProvider = _poTokenProvider != null;

      final cascade =
          <
            ({
              List<YoutubeApiClient> clients,
              bool requireWatchPage,
              String label,
            })
          >[
            if (signedIn && hasPoProvider) ...[
              (
                clients: const [YoutubeApiClient.webRemix],
                requireWatchPage: false,
                label: 'webRemix',
              ),
              (
                clients: const [YoutubeApiClient.visionosSabr],
                requireWatchPage: false,
                label: 'visionosSabr',
              ),
              (
                clients: const [
                  YoutubeApiClient.visionos,
                  YoutubeApiClient.androidVr,
                ],
                requireWatchPage: false,
                label: 'visionos+androidVr',
              ),
              (
                clients: const [YoutubeApiClient.tv],
                requireWatchPage: true,
                label: 'tv',
              ),
              (
                clients: const [YoutubeApiClient.androidMusic],
                requireWatchPage: false,
                label: 'androidMusic',
              ),
            ] else ...[
              (
                clients: const [
                  YoutubeApiClient.visionosSabr,
                  YoutubeApiClient.visionos,
                ],
                requireWatchPage: false,
                label: 'visionosSabr+visionos',
              ),
              (
                clients: const [YoutubeApiClient.androidVr],
                requireWatchPage: false,
                label: 'androidVr',
              ),
              if (hasPoProvider)
                (
                  clients: const [YoutubeApiClient.webRemix],
                  requireWatchPage: false,
                  label: 'webRemix',
                ),
              (
                clients: const [YoutubeApiClient.tv],
                requireWatchPage: true,
                label: 'tv',
              ),
              (
                clients: const [YoutubeApiClient.androidMusic],
                requireWatchPage: false,
                label: 'androidMusic',
              ),
            ],
          ];

      Object? firstError;
      StackTrace? firstStack;

      for (final step in cascade) {
        if (_scheduler.isCoolingDown && firstError != null) {
          Error.throwWithStackTrace(firstError, firstStack!);
        }
        try {
          return await _yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: step.clients,
            requireWatchPage: step.requireWatchPage,
          );
        } on RequestLimitExceededException {
          _scheduler.enterCoolDown();
          rethrow;
        } catch (error, stackTrace) {
          dev.log(
            '[StreamDatasource] ${step.label} failed for $videoId: $error',
          );
          firstError ??= error;
          firstStack ??= stackTrace;
        }
      }

      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
      throw VideoUnavailableException('No streams available for $videoId');
    });
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
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? audioQuality,
  }) async {
    final plan = await ensurePlaybackSelection(
      videoId,
      audioQuality: audioQuality ?? getDefaultAudioQuality(),
    );
    return plan.primaryUrl;
  }

  Future<StreamManifest> getManifest(String videoId) => _fetchManifest(videoId);

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
  /// interrupts playback. Skips entirely during a rate-limit cool-down.
  Future<void> cacheAudio(String videoId, {MediaQuality? audioQuality}) async {
    if (_scheduler.isCoolingDown) return;
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
          onProgress: (_, _) {},
        ),
      );
    } catch (e) {
      if (e is RequestLimitExceededException) {
        _scheduler.enterCoolDown();
      }
      dev.log('[StreamDatasource] cacheAudio failed for $videoId: $e');
    }
  }

  /// Returns a cached [SabrAudioStreamInfo] for [videoId] if resolved and
  /// still valid.
  SabrAudioStreamInfo? cachedSabrStream(
    String videoId, {
    MediaQuality? audioQuality,
  }) {
    final key = playbackKey(
      videoId,
      audioQuality: audioQuality ?? getDefaultAudioQuality(),
    );
    final cached = _playbackCache[key];
    if (cached == null || cached.isStale) return null;
    return cached.sabrStream;
  }

  /// Opens a controllable [SabrStream] for [stream].
  SabrStream openSabrStream(
    SabrAudioStreamInfo stream, {
    int initialPlayerTimeMs = 0,
    int Function()? playbackPositionMs,
  }) => _yt.videos.streamsClient.openSabrStream(
    stream,
    initialPlayerTimeMs: initialPlayerTimeMs,
    playbackPositionMs: playbackPositionMs,
  );

  /// Invalidates cached PO token session state (e.g. on account switch or
  /// `StreamProtectionStatus = 3`) and clears the stream URL cache.
  void invalidatePoTokenSession() {
    _poTokenProvider?.invalidateSession();
    clearUrlCache();
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
    _onDispose?.call();
  }
}
