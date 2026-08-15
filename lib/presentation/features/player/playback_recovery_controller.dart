import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/utils/connectivity_utils.dart';
import '../../../data/services/media_cache_service.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import 'play_error.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'queue_controller.dart';
import 'track_url_resolver.dart';

/// Handles playback error recovery and network-drop auto-resume.
///
/// **Responsibilities:**
/// - One-shot URL refresh retry on player errors
/// - Advancing to offline/cached tracks when connection fails
/// - Auto-resuming after network restoration
///
/// **Does NOT handle:**
/// - URL resolution for pending queue items ([TrackUrlResolver])
/// - Queue mutations beyond what retry/recovery requires
/// - Cast session lifecycle beyond the injected callbacks
///
/// Does not hold a back-reference to [SonoraAudioHandler]; playback intent,
/// cast state, and queue navigation are injected as narrow callbacks.
class PlaybackRecoveryController {
  final Player _player;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final QueueController _queueController;
  final PlaybackVolumeController _volumeController;
  final PlaybackStatePublisher _statePublisher;
  final TrackUrlResolver _urlResolver;
  final Connectivity _connectivity;
  final bool Function() _userWantsPlaying;
  final bool Function() _isStopping;
  final Future<void> Function() _requestPlay;
  final Future<void> Function(int index) _skipToQueueItem;
  final bool Function() _isCastConnected;
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

  int _retryCount = 0;
  bool _isRetrying = false;
  // Tracks the videoId of the last retried track so we can reset _retryCount
  // when a new track errors, even if _onPlaylistChanged's reset was suppressed
  // by _queueController.isResolvingItem being true during a concurrent URL resolution.
  String? _lastRetriedVideoId;
  StreamSubscription<String>? _playerErrorSub;
  bool _interruptedByNetworkDrop = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final StreamController<PlayErrorEvent> _onPlayErrorController =
      StreamController<PlayErrorEvent>.broadcast();

  Stream<PlayErrorEvent> get onPlayError => _onPlayErrorController.stream;

  void reportPlayError(
    String videoId,
    String title, {
    PlayErrorKind kind = PlayErrorKind.unknown,
    bool skippedToNext = false,
  }) {
    _onPlayErrorController.add(
      PlayErrorEvent(
        videoId: videoId,
        title: title,
        kind: kind,
        skippedToNext: skippedToNext,
      ),
    );
  }

  PlaybackRecoveryController({
    required Player player,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required QueueController queueController,
    required PlaybackVolumeController volumeController,
    required PlaybackStatePublisher statePublisher,
    required TrackUrlResolver urlResolver,
    required Connectivity connectivity,
    required bool Function() userWantsPlaying,
    required bool Function() isStopping,
    required Future<void> Function() requestPlay,
    required Future<void> Function(int index) skipToQueueItem,
    required bool Function() isCastConnected,
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
  }) : _player = player,
       _playVideoIdUseCase = playVideoIdUseCase,
       _queueController = queueController,
       _volumeController = volumeController,
       _statePublisher = statePublisher,
       _urlResolver = urlResolver,
       _connectivity = connectivity,
       _userWantsPlaying = userWantsPlaying,
       _isStopping = isStopping,
       _requestPlay = requestPlay,
       _skipToQueueItem = skipToQueueItem,
       _isCastConnected = isCastConnected,
       _setPausedForConnection = setPausedForConnection,
       _castMedia = castMedia,
       _waitForCastPlaying = waitForCastPlaying,
       _castPause = castPause;

  /// Resets the per-track error retry counter (e.g. on track change or ready).
  void resetRetryCount() => _retryCount = 0;

  /// Attaches player error and connectivity subscriptions.
  void startListening() {
    _playerErrorSub = _player.stream.error.listen(_onPlayerError);
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  Future<void> handlePlaybackConnectionFailure(
    String videoId,
    String title, {
    PlayErrorKind kind = PlayErrorKind.network,
  }) async {
    if (kind == PlayErrorKind.network) {
      _interruptedByNetworkDrop = true;
    }
    final playlist = _player.state.playlist;
    final currentIndex = playlist.index;
    if (currentIndex < 0) return;

    await advancePastUnplayable(
      currentIndex,
      stopIfNone: true,
      videoId: videoId,
      title: title,
      kind: kind,
    );
  }

  /// Skips forward from [failedIndex] to the next already-playable queue item
  /// (has URL / cached / local). Does not mark a network interruption.
  ///
  /// Always emits a [PlayErrorEvent] when [videoId] and [title] are provided.
  Future<void> advancePastUnplayable(
    int failedIndex, {
    bool stopIfNone = true,
    String? videoId,
    String? title,
    PlayErrorKind kind = PlayErrorKind.unknown,
  }) async {
    final playlist = _player.state.playlist;
    if (failedIndex < 0) return;

    int targetIndex = -1;
    for (int i = failedIndex + 1; i < playlist.medias.length; i++) {
      final mediaItem = playlist.medias[i].extras?['mediaItem'] as MediaItem?;
      if (mediaItem == null) continue;
      final track = QueueTrack.fromMediaItem(mediaItem);

      bool isCached = false;
      final cachedUri = await MediaCacheService.instance.getCachedFileUri(
        track.videoId,
      );
      isCached = cachedUri != null;

      final isUsableLocal = track.isLocalFile;

      if (isUsableLocal || isCached || !track.needsUrl) {
        targetIndex = i;
        break;
      }
    }

    final skippedToNext = targetIndex != -1;
    if (skippedToNext) {
      dev.log(
        '[AudioHandler] Advancing queue index past unplayable to $targetIndex.',
      );
      await _skipToQueueItem(targetIndex);
    } else if (stopIfNone) {
      dev.log(
        '[AudioHandler] No playable tracks after $failedIndex. Stopping playback.',
      );
      await _player.stop();
    }

    if (videoId != null && title != null) {
      reportPlayError(videoId, title, kind: kind, skippedToNext: skippedToNext);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (!_interruptedByNetworkDrop) return;
    if (results.isEmpty ||
        (results.length == 1 && results.contains(ConnectivityResult.none))) {
      return;
    }

    final isOnline = await ConnectivityUtils.isOnline();
    if (isOnline && _interruptedByNetworkDrop) {
      dev.log('[AudioHandler] Network connection restored. Auto-resuming...');
      _interruptedByNetworkDrop = false;
      final currentIndex = _player.state.playlist.index;
      if (currentIndex >= 0 &&
          currentIndex < _player.state.playlist.medias.length) {
        await _urlResolver.resolveSinglePendingItem(
          currentIndex,
          forceResolve: true,
        );
        await _requestPlay();
      }
    }
  }

  void _onPlayerError(String error) async {
    // Always lift any pending transition mute on error so the player does not
    // remain permanently muted (e.g., when a URL resolve fails inside playNow).
    _volumeController.endTransitionMute();

    // Source of truth is the playlist slot at the engine index — NOT
    // mediaItem.value, which can lag across a track change (especially while
    // isResolvingItem suppresses _onPlaylistChanged). Using the stale
    // MediaItem with the new index caused replaceAt to overwrite the next
    // track with a duplicate of the previous one.
    final playlistIndex = _player.state.playlist.index;
    final medias = _player.state.playlist.medias;
    if (playlistIndex < 0 || playlistIndex >= medias.length) return;
    final currentItem =
        medias[playlistIndex].extras?['mediaItem'] as MediaItem?;
    if (currentItem == null) return;
    final track = QueueTrack.fromMediaItem(currentItem);
    final videoId = track.videoId;

    // If this is a different track than the last retried one, reset the counter.
    // This ensures a new track always gets its one retry attempt, even when
    // _onPlaylistChanged's trackChanged reset was suppressed by _queueController.isResolvingItem.
    if (_lastRetriedVideoId != videoId) {
      _retryCount = 0;
    }

    if (_isRetrying || _retryCount >= 1 || _urlResolver.isPending(videoId)) {
      return;
    }

    _isRetrying = true;
    _lastRetriedVideoId = videoId;
    _retryCount++;
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(
        videoId,
        preferVideo: _queueController.prefersVideo(track),
      );

      // Re-read index after the await — user may have skipped meanwhile.
      final currentIndex = _player.state.playlist.index;
      final mediasAfter = _player.state.playlist.medias;
      if (currentIndex < 0 || currentIndex >= mediasAfter.length) return;
      final itemAtIndex =
          mediasAfter[currentIndex].extras?['mediaItem'] as MediaItem?;
      final idAtIndex =
          itemAtIndex != null
              ? QueueTrack.fromMediaItem(itemAtIndex).videoId
              : null;
      if (idAtIndex != videoId) {
        return;
      }

      final updatedItem = track
          .copyWith(url: freshUrl)
          .toMediaItem(currentItem);
      final updatedMedia = _queueController.toMedia(updatedItem);

      final wasPlaying = _player.state.playing || _userWantsPlaying();
      final currentPos = _player.state.position;

      try {
        await _queueController.runBatch(
          () async {
            if (_isCastConnected()) {
              // Cast is active: send the refreshed URL to the cast device too.
              if (wasPlaying) {
                _setPausedForConnection(true);
                await _player.pause();
              }
              _volumeController.setLocalVolume(0.0);

              await _castMedia(
                url: freshUrl,
                title: updatedItem.title,
                artist: updatedItem.artist,
                album: updatedItem.album,
                artworkUrl: updatedItem.artUri?.toString(),
              );

              // Update the local playlist with the refreshed URL.
              final replacedAt = await _queueController.replaceAtUnlocked(
                currentIndex,
                updatedMedia,
                expectedVideoId: videoId,
              );
              if (replacedAt < 0) return;
              await _player.jump(replacedAt);
              if (currentPos > Duration.zero) await _player.seek(currentPos);

              if (wasPlaying) {
                await _waitForCastPlaying();
                _setPausedForConnection(false);
                await _requestPlay();
              } else {
                await _castPause();
              }
            } else {
              if (wasPlaying) await _player.pause();
              final replacedAt = await _queueController.replaceAtUnlocked(
                currentIndex,
                updatedMedia,
                expectedVideoId: videoId,
              );
              if (replacedAt < 0) return;
              await _player.jump(replacedAt);

              if (currentPos > Duration.zero) {
                await _player.seek(currentPos);
              }
              if (wasPlaying) await _player.play();
            }
          },
          isStopping: _isStopping(),
          onSettled: () {
            _statePublisher.invalidate();
            _statePublisher.updatePlaybackState();
          },
        );
      } finally {
        final actualIndex = _player.state.playlist.index;
        if (actualIndex >= 0) {
          _statePublisher.updateState(
            (s) => s.copyWith(queueIndex: actualIndex),
          );
        }
      }
    } catch (e) {
      await handlePlaybackConnectionFailure(
        videoId,
        currentItem.title,
        kind: PlayErrorKind.classify(e),
      );
    } finally {
      _isRetrying = false;
    }
  }

  void dispose() {
    _playerErrorSub?.cancel();
    _connectivitySub?.cancel();
    _onPlayErrorController.close();
  }
}
