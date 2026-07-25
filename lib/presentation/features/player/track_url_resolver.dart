import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import '../../../data/services/media_cache_service.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
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
/// - Queue mutations beyond [QueueController.replaceAt]
/// - Playback control beyond the injected callbacks
/// - Connection-failure recovery (delegated to [onResolveFailed])
///
/// Does not hold a back-reference to [SonoraAudioHandler]; cast state,
/// playback intent, and failure handling are injected as narrow callbacks.
class TrackUrlResolver {
  final Player _player;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final QueueController _queueController;
  final PlaybackVolumeController _volumeController;
  final PlaybackStatePublisher _statePublisher;
  final bool Function() _isCastConnected;
  final bool Function() _userWantsPlaying;
  final bool Function() _isStopping;
  final Future<void> Function() _requestPlay;
  final Future<void> Function(String videoId, String title) _onResolveFailed;
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
  Timer? _lookaheadTimer;

  TrackUrlResolver({
    required Player player,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required QueueController queueController,
    required PlaybackVolumeController volumeController,
    required PlaybackStatePublisher statePublisher,
    required bool Function() isCastConnected,
    required bool Function() userWantsPlaying,
    required bool Function() isStopping,
    required Future<void> Function() requestPlay,
    required Future<void> Function(String videoId, String title)
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
  }) : _player = player,
       _playVideoIdUseCase = playVideoIdUseCase,
       _queueController = queueController,
       _volumeController = volumeController,
       _statePublisher = statePublisher,
       _isCastConnected = isCastConnected,
       _userWantsPlaying = userWantsPlaying,
       _isStopping = isStopping,
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

  void dispose() => _lookaheadTimer?.cancel();

  Future<void> resolvePendingItems(int currentIndex) async {
    await resolveSinglePendingItem(currentIndex);
    await resolveSinglePendingItem(currentIndex + 1);

    // Trigger pre-caching for the resolved upcoming track
    final playlist = _player.state.playlist;
    if (currentIndex + 1 < playlist.medias.length) {
      final media = playlist.medias[currentIndex + 1];
      final item = media.extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        final t = QueueTrack.fromMediaItem(item);
        if (t.hasUrl &&
            !t.isLocalFile &&
            !t.url!.startsWith('http://localhost')) {
          unawaited(
            MediaCacheService.instance.downloadToCache(t.videoId, t.url!),
          );
        }
      }
    }

    _lookaheadTimer?.cancel();
    _lookaheadTimer = Timer(const Duration(seconds: 20), () async {
      final actualIndex = _player.state.playlist.index;
      if (actualIndex == currentIndex && _player.state.playing) {
        await resolveSinglePendingItem(currentIndex + 2);
        if (currentIndex + 2 < playlist.medias.length) {
          final media2 = playlist.medias[currentIndex + 2];
          final item2 = media2.extras?['mediaItem'] as MediaItem?;
          if (item2 != null) {
            final t2 = QueueTrack.fromMediaItem(item2);
            if (t2.hasUrl &&
                !t2.isLocalFile &&
                !t2.url!.startsWith('http://localhost')) {
              unawaited(
                MediaCacheService.instance.downloadToCache(t2.videoId, t2.url!),
              );
            }
          }
        }

        await Future.delayed(const Duration(seconds: 3));
        final finalIndex = _player.state.playlist.index;
        if (finalIndex == currentIndex && _player.state.playing) {
          await resolveSinglePendingItem(currentIndex + 3);
          if (currentIndex + 3 < playlist.medias.length) {
            final media3 = playlist.medias[currentIndex + 3];
            final item3 = media3.extras?['mediaItem'] as MediaItem?;
            if (item3 != null) {
              final t3 = QueueTrack.fromMediaItem(item3);
              if (t3.hasUrl &&
                  !t3.isLocalFile &&
                  !t3.url!.startsWith('http://localhost')) {
                unawaited(
                  MediaCacheService.instance.downloadToCache(
                    t3.videoId,
                    t3.url!,
                  ),
                );
              }
            }
          }
        }
      }
    });
  }

  Future<void> resolveSinglePendingItem(
    int index, {
    bool forceResolve = false,
    // Overrides the auto-detected "is this the active item" check below.
    // Pass `true` when the caller is about to make [index] the active item
    // (e.g. [skipToQueueItem] resolving the tapped item *before* jumping to
    // it, when `_player.state.playlist.index` still points at the old
    // track) so it gets the long, 429-back-off-tolerant timeout instead of
    // the short background one.
    bool? treatAsCurrent,
  }) async {
    if (index < 0) return;
    final playlist = _player.state.playlist;
    if (index >= playlist.medias.length) return;
    final media = playlist.medias[index];
    final item = media.extras?['mediaItem'] as MediaItem?;
    if (item == null) return;
    final track = QueueTrack.fromMediaItem(item);
    if (!forceResolve && !track.needsUrl) return;

    final videoId = track.videoId;

    if (!_pendingResolutions.add(videoId)) return;
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
          .resolveUrl(videoId)
          .timeout(
            isCurrent
                ? PlayVideoIdUseCase.streamUrlTimeout +
                    const Duration(seconds: 5)
                : const Duration(seconds: 15),
          );

      final playlist2 = _player.state.playlist;
      if (index >= playlist2.medias.length) return;
      final currentMedia = playlist2.medias[index];
      final currentItem = currentMedia.extras?['mediaItem'] as MediaItem?;
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

      if (_isCastConnected()) {
        if (index == _player.state.playlist.index) {
          final wasPlaying = _player.state.playing || _userWantsPlaying();
          final currentPos = _player.state.position;
          if (wasPlaying) {
            _setPausedForConnection(true);
            await _player.pause();
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
          await _queueController.replaceAt(index, updatedMedia);
          await _player.jump(index);
          if (currentPos > Duration.zero) await _player.seek(currentPos);

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
          await _queueController.replaceAt(index, updatedMedia);
        }
      } else {
        if (index == _player.state.playlist.index) {
          final wasPlaying = _player.state.playing;
          final currentPos = _player.state.position;
          if (wasPlaying) await _player.pause();
          await _queueController.replaceAt(index, updatedMedia);
          await _player.jump(index);
          if (currentPos > Duration.zero) await _player.seek(currentPos);
          if (wasPlaying) await _player.play();
        } else {
          await _queueController.replaceAt(index, updatedMedia);
        }
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to resolve URL for item at $index: $e');
      final playlist3 = _player.state.playlist;
      if (index == playlist3.index) {
        await _onResolveFailed(videoId, item.title);
      }
    } finally {
      _queueController.endResolving();
      _pendingResolutions.remove(videoId);
      _queueController.syncQueue(isStopping: _isStopping());
      if (!_queueController.isResolvingItem) {
        _statePublisher.invalidate();
        _statePublisher.updatePlaybackState();
      }
      final actualIndex = _player.state.playlist.index;
      if (actualIndex >= 0) {
        _statePublisher.updateState((s) => s.copyWith(queueIndex: actualIndex));
        final playlist = _player.state.playlist;
        if (actualIndex < playlist.medias.length) {
          final media = playlist.medias[actualIndex];
          final item = media.extras?['mediaItem'] as MediaItem?;
          if (item != null) {
            _statePublisher.noteEmittedMediaItem(item);
            _emitMediaItem(item);
          }
        }
      }
    }
  }
}
