import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import 'playback_intent_controller.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'queue_controller.dart';

/// Owns the three ways the playlist gets replaced wholesale: [setQueue],
/// [playNow] and [rebuildMedia].
///
/// All of them run through [runExclusive], the same FIFO lock that serialises
/// queue mutations, so "Add to Queue" cannot interleave with "Play All" or with
/// a URL swap and leave the engine holding a half-written playlist.
///
/// ## The abort protocol
///
/// A caller that may be superseded passes `shouldAbort`. It is evaluated *after*
/// any in-flight open completes, immediately before this one would touch the
/// player, so the most recent caller always wins and an obsolete one never
/// reaches the engine. `PlayerNotifier` implements it as an `_operationVersion`
/// identity check: tapping three albums quickly opens only the third.
///
/// ## Why the two open paths differ
///
/// [setQueue] opens with `play: false` — it stages a queue. [playNow] is an
/// explicit user session: it requests audio focus, resolves the first track's
/// URL up front so playback starts without a gap, and opens with `play: true`
/// only if focus was granted.
class PlaylistOpenCoordinator {
  final Player _player;
  final QueueController _queueController;
  final QueueRepository _queueRepo;
  final PlaybackVolumeController _volumeController;
  final PlaybackStatePublisher _statePublisher;
  final PlaybackIntentController _intent;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final Future<bool> Function() _requestFocus;
  final void Function(List<MediaItem>) _emitQueue;
  final bool Function() _isStopping;
  final void Function(bool) _setIsStopping;
  final void Function(String) _log;

  PlaylistOpenCoordinator({
    required Player player,
    required QueueController queueController,
    required QueueRepository queueRepo,
    required PlaybackVolumeController volumeController,
    required PlaybackStatePublisher statePublisher,
    required PlaybackIntentController intent,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required Future<bool> Function() requestFocus,
    required void Function(List<MediaItem>) emitQueue,
    required bool Function() isStopping,
    required void Function(bool) setIsStopping,
    required void Function(String) log,
  }) : _player = player,
       _queueController = queueController,
       _queueRepo = queueRepo,
       _volumeController = volumeController,
       _statePublisher = statePublisher,
       _intent = intent,
       _playVideoIdUseCase = playVideoIdUseCase,
       _requestFocus = requestFocus,
       _emitQueue = emitQueue,
       _isStopping = isStopping,
       _setIsStopping = setIsStopping,
       _log = log;

  /// Serialises a playlist rebuild through the queue lock, skipping it entirely
  /// when [shouldAbort] says this caller has been superseded.
  Future<void> runExclusive(
    Future<void> Function() action, {
    bool Function()? shouldAbort,
  }) async {
    await _queueController.runExclusive(() async {
      if (shouldAbort?.call() ?? false) return;
      await action();
    });
  }

  /// Replaces the queue and stages it paused.
  Future<void> setQueue(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) async {
    _setIsStopping(false);
    _volumeController.prepareTransitionMute();
    await runExclusive(() async {
      _queueController.beginResolving();
      try {
        final (itemsWithKeys, medias) = _queueController.preparePlaylist(
          items,
          initialIndex: initialIndex,
        );
        _emitQueue(itemsWithKeys);
        // A brand-new playback session starts at position 0 — explicitly
        // reset the persisted position so a process death right after this
        // call can't resume with a stale position left over from whatever
        // was playing before.
        await _queueRepo.persistQueue(
          itemsWithKeys,
          currentIndex: initialIndex,
          position: Duration.zero,
        );
        final playlist = Playlist(medias, index: initialIndex);
        _intent.onQueueReplaced();
        await _player.open(playlist, play: false);
      } catch (e) {
        _volumeController.endTransitionMute();
        rethrow;
      } finally {
        _endResolving();
      }
    }, shouldAbort: shouldAbort);
  }

  /// Starts an explicit user session on [items].
  Future<void> playNow(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) async {
    _setIsStopping(false);
    // playNow is an explicit user-initiated session. pauseFromUser() (called
    // by playAlbum/playPlaylist/etc.) marks an explicit pause; leaving it set
    // here makes playing.listen immediately pause() the new playlist.
    _intent.onNewSessionStarted();
    _volumeController.prepareTransitionMute();
    await runExclusive(() async {
      _queueController.beginResolving();
      try {
        final (itemsWithKeys, medias) = _queueController.preparePlaylist(
          items,
          initialIndex: initialIndex,
        );
        var resolvedItems = itemsWithKeys;
        _emitQueue(resolvedItems);
        // Same reasoning as setQueue: a brand-new session starts at 0.
        await _queueRepo.persistQueue(
          resolvedItems,
          currentIndex: initialIndex,
          position: Duration.zero,
        );

        resolvedItems = await _resolveInitialUrl(resolvedItems, initialIndex);

        final finalMedias =
            resolvedItems.map(_queueController.toMedia).toList();
        final playlist = Playlist(finalMedias, index: initialIndex);
        final hasFocus = await _requestFocus();
        _intent.onSessionOpened(hasFocus: hasFocus);
        await _player.open(playlist, play: hasFocus);
      } catch (e) {
        _volumeController.endTransitionMute();
        rethrow;
      } finally {
        _endResolving();
      }
    }, shouldAbort: shouldAbort);
  }

  /// Resolves the first track's URL before opening, so playback starts without
  /// waiting on the lazy resolver. A failure is logged and left to the resolver.
  Future<List<MediaItem>> _resolveInitialUrl(
    List<MediaItem> items,
    int initialIndex,
  ) async {
    if (initialIndex < 0 || initialIndex >= items.length) return items;

    final initialItem = items[initialIndex];
    final track = QueueTrack.fromMediaItem(initialItem);
    if (!track.needsUrl) return items;

    try {
      final url = await _playVideoIdUseCase.resolveUrl(
        track.videoId,
        preferVideo: _queueController.prefersVideo(track),
      );
      final resolved = track
          .copyWith(url: url, needsUrl: false)
          .toMediaItem(initialItem);
      final updated = List<MediaItem>.from(items);
      updated[initialIndex] = resolved;
      _emitQueue(updated);
      await _queueRepo.persistQueue(updated, currentIndex: initialIndex);
      return updated;
    } catch (e) {
      _log(
        '[AudioHandler] Failed to resolve initial item URL for ${track.videoId}: $e',
      );
      return items;
    }
  }

  void _endResolving() {
    _queueController.endResolving();
    if (!_queueController.isResolvingItem) {
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
    }
  }

  /// Rebuilds every [Media] in place after the stream quality or the
  /// audio/video mode changed, so the playlist picks up new proxy URLs without
  /// interrupting what is currently playing.
  Future<void> rebuildMedia() async {
    final playlist = _player.state.playlist;
    if (playlist.medias.isEmpty) return;
    final items = [
      for (final media in playlist.medias)
        media.extras?['mediaItem'] as MediaItem?,
    ];
    final index = playlist.index;
    final pos = _player.state.position;
    final wasPlaying = _player.state.playing;
    await _queueController.runBatch(() async {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item == null) continue;
        await _queueController.replaceAtUnlocked(
          i,
          _queueController.toMedia(item),
        );
      }
      if (index >= 0 && index < _player.state.playlist.medias.length) {
        await _player.jump(index);
        if (pos > Duration.zero) await _player.seek(pos);
        if (wasPlaying) await _player.play();
      }
    }, isStopping: _isStopping());
  }
}
