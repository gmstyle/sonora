import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'playback_engine.dart';

import '../../../data/services/media_cache_service.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'play_error.dart';
import 'queue_controller.dart';

/// Resolves pending stream URLs for queue tracks and manages look-ahead
/// pre-fetching.
///
/// **Responsibilities:**
/// - Resolving `needsUrl` tracks via [PlayVideoIdUseCase]
/// - Look-ahead timer for background resolution of upcoming items
/// - Cast-aware playlist replacement when a URL becomes available
/// - Pre-caching resolved upcoming tracks via [MediaCacheService]
///
/// **Does NOT handle:**
/// - Queue mutations beyond [QueueController.replaceAt] (`PlaybackEngine.replace`)
/// - Playback control beyond the injected callbacks
/// - Connection-failure recovery (delegated to [onResolveFailed])
///
/// Does not hold a back-reference to [SonoraAudioHandler]; cast state,
/// playback intent, and failure handling are injected as narrow callbacks.
class TrackUrlResolver {
  final PlaybackEngine _engine;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final QueueController _queueController;
  final PlaybackVolumeController _volumeController;
  final PlaybackStatePublisher _statePublisher;
  final bool Function() _isCastConnected;
  final bool Function() _userWantsPlaying;
  final bool Function() _isStopping;
  final bool Function() _isRestoring;
  final Future<void> Function() _requestPlay;
  final Future<void> Function(String videoId, String title, PlayErrorKind kind)
  _onResolveFailed;
  final void Function(MediaItem item) _emitMediaItem;
  final void Function(bool) _setPausedForConnection;
  final Future<void> Function({
    required String url,
    required String title,
    String? artist,
    String? album,
    String? artworkUrl,
  })
  _castMedia;
  final Future<void> Function() _waitForCastPlaying;
  final Future<void> Function() _castPause;

  final Set<String> _pendingResolutions = {};

  /// Video IDs whose engine URI is already playable (proxy/file) so a later
  /// YouTube resolve must not pause/swap the currently playing source.
  final Set<String> _engineUriReady = {};
  final Set<String> _prefetchInFlight = {};
  Timer? _lookaheadTimer;
  PlayErrorKind? _lastResolveFailureKind;

  /// Kind of the most recent [resolveSinglePendingItem] failure, if any.
  PlayErrorKind? get lastResolveFailureKind => _lastResolveFailureKind;

  TrackUrlResolver({
    required PlaybackEngine engine,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required QueueController queueController,
    required PlaybackVolumeController volumeController,
    required PlaybackStatePublisher statePublisher,
    required bool Function() isCastConnected,
    required bool Function() userWantsPlaying,
    required bool Function() isStopping,
    required bool Function() isRestoring,
    required Future<void> Function() requestPlay,
    required Future<void> Function(
      String videoId,
      String title,
      PlayErrorKind kind,
    )
    onResolveFailed,
    required void Function(MediaItem item) emitMediaItem,
    required void Function(bool) setPausedForConnection,
    required Future<void> Function({
      required String url,
      required String title,
      String? artist,
      String? album,
      String? artworkUrl,
    })
    castMedia,
    required Future<void> Function() waitForCastPlaying,
    required Future<void> Function() castPause,
  }) : _engine = engine,
       _playVideoIdUseCase = playVideoIdUseCase,
       _queueController = queueController,
       _volumeController = volumeController,
       _statePublisher = statePublisher,
       _isCastConnected = isCastConnected,
       _userWantsPlaying = userWantsPlaying,
       _isStopping = isStopping,
       _isRestoring = isRestoring,
       _requestPlay = requestPlay,
       _onResolveFailed = onResolveFailed,
       _emitMediaItem = emitMediaItem,
       _setPausedForConnection = setPausedForConnection,
       _castMedia = castMedia,
       _waitForCastPlaying = waitForCastPlaying,
       _castPause = castPause;

  /// Returns `true` while a resolution for [videoId] is in flight.
  bool isPending(String videoId) => _pendingResolutions.contains(videoId);

  /// Cancels the look-ahead resolution timer without disposing the resolver.
  void cancelLookahead() => _lookaheadTimer?.cancel();

  /// Drops the "already playable via proxy" skip-list. Call when the playlist
  /// is replaced wholesale ([setQueue] / [playNow]).
  void resetSession() => _engineUriReady.clear();

  void dispose() {
    _lookaheadTimer?.cancel();
    _engineUriReady.clear();
    // Teardown: stop every disk pre-cache download this resolver started.
    for (final videoId in _prefetchInFlight) {
      MediaCacheService.instance.cancelDownload(videoId);
    }
    _prefetchInFlight.clear();
  }

  Future<void> resolvePendingItems(int currentIndex) async {
    // Prune disk pre-cache downloads the user has moved past (skipped ahead,
    // replaced queue, auto-advanced) before starting any new lookahead work.
    final stale = _stalePrefetchVideoIds(currentIndex);
    for (final videoId in stale) {
      _prefetchInFlight.remove(videoId);
      MediaCacheService.instance.cancelDownload(videoId);
    }

    await resolveSinglePendingItem(currentIndex);
    await resolveSinglePendingItem(currentIndex + 1);

    // Always re-read playlist after resolve — a captured snapshot would still
    // have needsUrl / dummy URL and skip the disk pre-cache.
    _prefetchDiskCacheAt(currentIndex + 1);

    _lookaheadTimer?.cancel();
    _lookaheadTimer = Timer(const Duration(seconds: 20), () async {
      final actualIndex = _engine.state.playlist.index;
      if (actualIndex == currentIndex && _engine.state.playing) {
        await resolveSinglePendingItem(currentIndex + 2);
        _prefetchDiskCacheAt(currentIndex + 2);

        await Future.delayed(const Duration(seconds: 3));
        final finalIndex = _engine.state.playlist.index;
        if (finalIndex == currentIndex && _engine.state.playing) {
          await resolveSinglePendingItem(currentIndex + 3);
          _prefetchDiskCacheAt(currentIndex + 3);
        }
      }
    });
  }

  /// Kicks off a disk cache download for [index] using a fresh playlist read.
  void _prefetchDiskCacheAt(int index) {
    final playlist = _engine.state.playlist;
    if (index < 0 || index >= playlist.medias.length) return;
    final media = playlist.medias[index];
    final item = media.mediaItem;
    if (item == null) return;
    final track = QueueTrack.fromMediaItem(item);
    final url = diskPrefetchUrlFor(item);
    final videoId = track.videoId;
    if (!_prefetchInFlight.add(videoId)) return;
    unawaited(() async {
      try {
        if (url == null) return;
        await MediaCacheService.instance.downloadToCache(videoId, url);
      } catch (_) {
      } finally {
        _prefetchInFlight.remove(videoId);
      }
    }());
  }

  /// videoIds of disk pre-cache downloads that are no longer relevant for
  /// [currentIndex]: every in-flight id outside the `currentIndex..+3`
  /// lookahead window of [queueVideoIds].
  @visibleForTesting
  static Set<String> stalePrefetchIds({
    required Set<String> inFlight,
    required List<String?> queueVideoIds,
    required int currentIndex,
  }) {
    if (queueVideoIds.isEmpty) return inFlight;
    final keep = <String>{};
    final last = math.min(currentIndex + 3, queueVideoIds.length - 1);
    for (var i = math.max(currentIndex, 0); i <= last; i++) {
      final id = queueVideoIds[i];
      if (id != null && id.isNotEmpty) keep.add(id);
    }
    return inFlight.difference(keep);
  }

  Set<String> _stalePrefetchVideoIds(int currentIndex) {
    final playlist = _engine.state.playlist;
    return stalePrefetchIds(
      inFlight: _prefetchInFlight,
      queueVideoIds: [
        for (final media in playlist.medias)
          () {
            final item = media.mediaItem;
            if (item == null) return null;
            return QueueTrack.fromMediaItem(item).videoId;
          }(),
      ],
      currentIndex: currentIndex,
    );
  }

  /// URL eligible for disk look-ahead pre-cache, or null if the item must not
  /// be downloaded (unresolved, local file, or dummy placeholder).
  @visibleForTesting
  static String? diskPrefetchUrlFor(MediaItem? item) {
    if (item == null) return null;
    final t = QueueTrack.fromMediaItem(item);
    if (t.hasUrl && !t.isLocalFile && !t.url!.startsWith('http://localhost')) {
      return t.url;
    }
    return null;
  }

  Future<void> resolveSinglePendingItem(
    int index, {
    bool forceResolve = false,
    // Overrides the auto-detected "is this the active item" check below.
    // Pass `true` when the caller is about to make [index] the active item
    // (e.g. [skipToQueueItem] resolving the tapped item *before* jumping to
    // it, when `_engine.state.playlist.index` still points at the old
    // track) so it gets the long, 429-back-off-tolerant timeout instead of
    // the short background one.
    bool? treatAsCurrent,
  }) async {
    if (index < 0) return;
    final playlist = _engine.state.playlist;
    if (index >= playlist.medias.length) return;
    final media = playlist.medias[index];
    final item = media.mediaItem;
    if (item == null) return;
    final track = QueueTrack.fromMediaItem(item);
    if (!forceResolve && !track.needsUrl) return;

    final videoId = track.videoId;
    if (!forceResolve && _engineUriReady.contains(videoId)) return;

    if (!_pendingResolutions.add(videoId)) return;
    _lastResolveFailureKind = null;
    _queueController.beginResolving();
    try {
      // The active (currently playing/selected) item gets enough headroom
      // to survive PlayVideoIdUseCase.streamUrlTimeout's full anti-429
      // back-off cycle — aborting early here would defeat that back-off and
      // strand playback on a dummy/expired URL for no reason (this is the
      // #1 cause of "tapping a queue item does nothing" after the app has
      // been idle for a while). Background (look-ahead) items use a much
      // shorter bound since they are not blocking playback and will simply
      // be re-resolved once they actually become current.
      final isCurrent = treatAsCurrent ?? (index == playlist.index);
      final url = await _playVideoIdUseCase
          .resolveUrl(
            videoId,
            preferVideo: _queueController.prefersVideo(track),
          )
          .timeout(
            isCurrent
                ? PlayVideoIdUseCase.streamUrlTimeout +
                    const Duration(seconds: 5)
                : const Duration(seconds: 15),
          );

      final playlist2 = _engine.state.playlist;
      if (index >= playlist2.medias.length) return;
      final currentMedia = playlist2.medias[index];
      final currentItem = currentMedia.mediaItem;
      final currentTrack =
          currentItem != null ? QueueTrack.fromMediaItem(currentItem) : null;
      if (currentTrack?.videoId != videoId) return;
      if (!forceResolve && currentTrack?.needsUrl != true) return;
      // Abort background pre-fetch if the user has skipped past this item.
      if (!isCurrent && playlist2.index > index) return;

      final updatedItem = track
          .copyWith(url: url, needsUrl: false)
          .toMediaItem(currentItem ?? item);
      final updatedMedia = _queueController.toMedia(updatedItem);

      // Proxy/file URI is already on the engine; swapping the current source
      // would glitch playback. Remember so lookahead does not retry Innertube.
      final isPlayingSlot = index == _engine.state.playlist.index;
      if (updatedMedia.uri == currentMedia.uri &&
          isPlayingSlot &&
          !_isCastConnected()) {
        _engineUriReady.add(videoId);
        return;
      }

      if (_isCastConnected()) {
        if (index == _engine.state.playlist.index) {
          final wasPlaying = _engine.state.playing || _userWantsPlaying();
          final currentPos = _engine.state.position;
          if (wasPlaying) {
            _setPausedForConnection(true);
            await _engine.pause();
          }
          _volumeController.setLocalVolume(0.0);

          await _castMedia(
            url: url,
            title: updatedItem.title,
            artist: updatedItem.artist,
            album: updatedItem.album,
            artworkUrl: updatedItem.artUri?.toString(),
          );

          // Update the local playlist with the resolved URL so local playback
          // can resume correctly if the cast session is disconnected later.
          final replacedAt = await _queueController.replaceAt(
            index,
            updatedMedia,
            expectedVideoId: videoId,
          );
          if (replacedAt < 0) return;
          await _engine.jump(replacedAt);
          if (currentPos > Duration.zero) await _engine.seek(currentPos);

          if (wasPlaying) {
            await _waitForCastPlaying();
            _setPausedForConnection(false);
            // Use play() (not _player.play()) so castService?.play() is also
            // sent to the cast device, keeping local player and cast in sync.
            await _requestPlay();
          } else {
            await _castPause();
          }
        } else {
          await _queueController.replaceAt(
            index,
            updatedMedia,
            expectedVideoId: videoId,
          );
        }
      } else {
        if (index == _engine.state.playlist.index) {
          final wasPlaying = _engine.state.playing;
          final currentPos = _engine.state.position;
          if (wasPlaying) await _engine.pause();
          final replacedAt = await _queueController.replaceAt(
            index,
            updatedMedia,
            expectedVideoId: videoId,
          );
          if (replacedAt < 0) return;
          await _engine.jump(replacedAt);
          if (currentPos > Duration.zero) await _engine.seek(currentPos);
          if (wasPlaying) await _engine.play();
        } else {
          await _queueController.replaceAt(
            index,
            updatedMedia,
            expectedVideoId: videoId,
          );
        }
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to resolve URL for item at $index: $e');
      final kind = PlayErrorKind.classify(e);
      _lastResolveFailureKind = kind;
      final playlist3 = _engine.state.playlist;
      if (index == playlist3.index) {
        await _onResolveFailed(videoId, item.title, kind);
      }
    } finally {
      _queueController.endResolving();
      _pendingResolutions.remove(videoId);
      _queueController.syncQueue(isStopping: _isStopping());
      if (!_queueController.isResolvingItem) {
        _statePublisher.invalidate();
        _statePublisher.updatePlaybackState();
      }
      final actualIndex = _engine.state.playlist.index;
      if (actualIndex >= 0 && !_isRestoring()) {
        _statePublisher.updateState((s) => s.copyWith(queueIndex: actualIndex));
        final playlist = _engine.state.playlist;
        if (actualIndex < playlist.medias.length) {
          final media = playlist.medias[actualIndex];
          var item = media.mediaItem;
          if (item != null) {
            // Look-ahead resolves re-emit the *current* MediaItem from playlist
            // extras. If metadata had duration 0/null, that would wipe a
            // player-derived duration already published to Android Auto.
            // Only copy player duration when this is still the same track —
            // after a skip, player.state.duration is often still the previous
            // track's length and would stick forever (duration listener skips
            // once MediaItem.duration is non-zero).
            var track = QueueTrack.fromMediaItem(item);
            final trackChanged =
                track.videoId != _statePublisher.lastEmittedMediaItemId;
            final playerDuration = _engine.state.duration;
            if (!trackChanged &&
                (track.duration == null || track.duration == Duration.zero) &&
                playerDuration > Duration.zero) {
              track = track.copyWith(duration: playerDuration);
              item = track.toMediaItem(item);
            }
            _statePublisher.noteEmittedMediaItem(item, track: track);
            _emitMediaItem(item);
          }
        }
      }
    }
  }
}
