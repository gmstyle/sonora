import 'dart:async';
import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:media_kit/media_kit.dart';
import '../../../data/services/local_audio_proxy_server.dart';
import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';

import 'package:dart_cast/dart_cast.dart';
import '../../providers/cast_provider.dart';
import '../../../data/services/cast_service.dart';

import 'android_auto_browser_controller.dart';
import 'cast_playback_controller.dart';
import 'equalizer_controller.dart';
import 'audio_session_controller.dart';
import 'external_audio_track_controller.dart';
import 'like_controller.dart';
import 'play_error.dart';
import 'player_engine_configurator.dart';
import 'player_media_controls.dart';
import 'playback_recovery_controller.dart';
import 'playback_restore_controller.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'queue_controller.dart';
import 'skip_navigator.dart';
import 'track_url_resolver.dart';

export 'playback_restore_controller.dart' show RestoreStatus;
export 'play_error.dart' show PlayErrorEvent, PlayErrorKind;

import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/models/media_quality.dart';
import '../../providers/settings_provider.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final Player _player = Player(
    configuration: const PlayerConfiguration(pitch: true),
  );
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  final LocalAudioProxyServer? _proxyServer;
  late final StartRadioUseCase _startRadioUseCase;

  late final CastPlaybackController _castController;
  late final AndroidAutoBrowserController _browserController;
  late final EqualizerController _equalizerController;
  late final QueueController _queueController;
  late final AudioSessionController _audioSessionController;
  late final PlayerEngineConfigurator _engineConfigurator;
  late final LikeController _likeController;
  late final PlaybackVolumeController _volumeController;
  late final PlaybackStatePublisher _statePublisher;
  late final SkipNavigator _skipNavigator;
  late final TrackUrlResolver _urlResolver;
  late final PlaybackRecoveryController _recoveryController;
  late final PlaybackRestoreController _restoreController;
  late final ExternalAudioTrackController _externalAudio;

  /// Single [Connectivity] instance shared across the entire player module.
  /// Avoids multiple platform-channel registrations for the same signal.
  static final Connectivity _sharedConnectivity = Connectivity();

  Player get player => _player;
  LocalAudioProxyServer? get proxyServer => _proxyServer;

  /// Syncs stream quality / video playback prefs used when building proxy URLs.
  /// Rebuilds in-memory [Media] sources when the playback mode or quality
  /// actually changes so the current playlist picks up new proxy URLs.
  void updateStreamPrefs({
    MediaQuality? streamAudioQuality,
    bool? enableVideoPlayback,
  }) {
    final audioChanged =
        streamAudioQuality != null &&
        streamAudioQuality != _queueController.streamAudioQuality;
    final enableChanged =
        enableVideoPlayback != null &&
        enableVideoPlayback != _queueController.enableVideoPlayback;
    _queueController.updateStreamPrefs(
      streamAudioQuality: streamAudioQuality,
      enableVideoPlayback: enableVideoPlayback,
    );
    if (audioChanged || enableChanged) {
      unawaited(_rebuildPlaylistMedia());
    }
  }

  Future<void> _persistPlaybackPointer() async {
    // During cold restore, media_kit seek is async: endResolving used to
    // persist position 0 and wipe the just-restored pointer before seek landed.
    if (_restoreController.isRestoring) return;

    final playlist = _player.state.playlist;
    final index = playlist.index;
    if (index < 0) return;
    String? videoId;
    if (index < playlist.medias.length) {
      final item = playlist.medias[index].extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        videoId = QueueTrack.fromMediaItem(item).videoId;
      }
    }
    await _queueRepo.persistPlaybackPointer(
      currentIndex: index,
      videoId: videoId,
      position: _player.state.position,
    );
  }

  Future<void> _rebuildPlaylistMedia() async {
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
    }, isStopping: _isStopping);
  }

  bool _isStopping = false;
  bool _userWantsPlaying = false;

  /// Serializes playlist rebuilds (setQueue / playNow) through the same FIFO
  /// lock as queue mutations, so Add to Queue cannot race Play All / URL swaps.
  ///
  /// When [shouldAbort] is provided it is evaluated right before the
  /// action runs (i.e. after any in-flight action completes); if it
  /// returns `true` the action is skipped entirely, so an obsolete caller
  /// never touches the player — the most recent call always wins.
  Future<void> _synchronizedOpen(
    Future<void> Function() action, {
    bool Function()? shouldAbort,
  }) async {
    await _queueController.runExclusive(() async {
      if (shouldAbort?.call() ?? false) return;
      await action();
    });
  }

  Stream<PlayErrorEvent> get onPlayError => _recoveryController.onPlayError;

  SonoraAudioHandler({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required SharedPreferences prefs,
    required QueueRepository queueRepo,
    LocalAudioProxyServer? proxyServer,
  }) : _playVideoIdUseCase = playVideoIdUseCase,
       _prefs = prefs,
       _queueRepo = queueRepo,
       _proxyServer = proxyServer {
    _externalAudio = ExternalAudioTrackController(player: _player);
    _startRadioUseCase = StartRadioUseCase(musicRepo);

    _likeController = LikeController(
      libraryRepo: libraryRepo,
      onLikeChanged: () => _rebuildControls(),
    );

    _equalizerController = EqualizerController(player: _player);

    _queueController = QueueController(
      player: _player,
      queueRepo: _queueRepo,
      getQueue: () => queue.value,
      getShuffleMode: () => playbackState.value.shuffleMode,
      getRepeatMode: () => playbackState.value.repeatMode,
      updateQueueStream: (items) => queue.add(items),
      proxyServer: _proxyServer,
      streamAudioQuality: MediaQuality.fromStorage(
        _prefs.getString(kStreamAudioQualityKey) ??
            _prefs.getString(kStreamQualityKey),
      ),
      enableVideoPlayback: _prefs.getBool(kEnableVideoPlaybackKey) ?? false,
    );

    _queueController.onResolvingIdle = () {
      unawaited(_persistPlaybackPointer());
    };

    // After QueueController so userQueue/upNextQueue callbacks are valid.
    _browserController = AndroidAutoBrowserController(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
      connectivity: _sharedConnectivity,
      userQueue: () => _queueController.userQueue,
      upNextQueue: () => _queueController.upNextQueue,
      currentMediaItem: () => mediaItem.valueOrNull,
      awaitReady: () => _restoreController.awaitReady(),
      playNow: (items) => playNow(items),
    );

    _engineConfigurator = PlayerEngineConfigurator(player: _player);
    // Volume must be constructed before cast so CastPlaybackController can
    // receive it; isCastConnected is late-bound and safe once cast is assigned.
    _volumeController = PlaybackVolumeController(
      player: _player,
      isCastConnected:
          () =>
              _castController.castState?.connectionState ==
              CastConnectionState.connected,
    );
    _castController = CastPlaybackController(
      player: _player,
      volumeController: _volumeController,
      playVideoIdUseCase: _playVideoIdUseCase,
      userWantsPlaying: () => _userWantsPlaying,
      currentMediaItem: () => mediaItem.value,
      requestPlay: play,
    );
    _statePublisher = PlaybackStatePublisher(
      player: _player,
      getPlaybackState: () => playbackState.value,
      setPlaybackState: (state) => playbackState.add(state),
      isRestoring: () => _restoreController.isRestoring,
      isResolving: () => _queueController.isResolvingItem,
      savedPosition: () => _restoreController.savedPosition,
      isLiked: () => _likeController.isCurrentSongLiked,
      onBecameReady: () => _recoveryController.resetRetryCount(),
    );
    _skipNavigator = SkipNavigator();
    _urlResolver = TrackUrlResolver(
      player: _player,
      playVideoIdUseCase: _playVideoIdUseCase,
      queueController: _queueController,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      streamDatasource: _proxyServer?.streamDatasource,
      isCastConnected:
          () =>
              _castController.castState?.connectionState ==
              CastConnectionState.connected,
      userWantsPlaying: () => _userWantsPlaying,
      isStopping: () => _isStopping,
      isRestoring: () => _restoreController.isRestoring,
      requestPlay: play,
      onResolveFailed:
          (videoId, title, kind) => _recoveryController
              .handlePlaybackConnectionFailure(videoId, title, kind: kind),
      emitMediaItem: (item) => mediaItem.add(item),
      setPausedForConnection: (v) => _castController.pausedForConnection = v,
      castMedia: ({
        required String url,
        required String title,
        String? artist,
        String? album,
        String? artworkUrl,
      }) async {
        await _castController.castService?.castMedia(
          url: url,
          title: title,
          artist: artist,
          album: album,
          artworkUrl: artworkUrl,
        );
      },
      waitForCastPlaying:
          () => _castController.waitForCastSessionState(
            _castController.castService!,
            SessionState.playing,
          ),
      castPause: () async {
        await _castController.castService?.pause();
      },
    );
    _recoveryController = PlaybackRecoveryController(
      player: _player,
      playVideoIdUseCase: _playVideoIdUseCase,
      queueController: _queueController,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      urlResolver: _urlResolver,
      connectivity: _sharedConnectivity,
      userWantsPlaying: () => _userWantsPlaying,
      isStopping: () => _isStopping,
      requestPlay: play,
      skipToQueueItem: skipToQueueItem,
      isCastConnected:
          () =>
              _castController.castState?.connectionState ==
              CastConnectionState.connected,
      setPausedForConnection: (v) => _castController.pausedForConnection = v,
      castMedia: ({
        required String url,
        required String title,
        String? artist,
        String? album,
        String? artworkUrl,
      }) async {
        await _castController.castService?.castMedia(
          url: url,
          title: title,
          artist: artist,
          album: album,
          artworkUrl: artworkUrl,
        );
      },
      waitForCastPlaying:
          () => _castController.waitForCastSessionState(
            _castController.castService!,
            SessionState.playing,
          ),
      castPause: () async {
        await _castController.castService?.pause();
      },
    );
    _restoreController = PlaybackRestoreController(
      player: _player,
      prefs: _prefs,
      queueRepo: _queueRepo,
      queueController: _queueController,
      urlResolver: _urlResolver,
      statePublisher: _statePublisher,
      playVideoIdUseCase: _playVideoIdUseCase,
      setUserWantsPlaying: (v) => _userWantsPlaying = v,
      emitMediaItem: (item) => mediaItem.add(item),
      applyShuffleMode: (shuffleMode) async {
        await _player.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
        _statePublisher.updateState(
          (s) => s.copyWith(shuffleMode: shuffleMode),
        );
      },
      applyRepeatMode: (repeatMode) async {
        final playlistMode = switch (repeatMode) {
          AudioServiceRepeatMode.none => PlaylistMode.none,
          AudioServiceRepeatMode.one => PlaylistMode.single,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => PlaylistMode.loop,
        };
        await _player.setPlaylistMode(playlistMode);
        _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
      },
      updateQueueStream: (items) => queue.add(items),
      setIsStopping: (v) => _isStopping = v,
      onRestoreReady: _notifyAndroidAutoResumption,
    );
    _audioSessionController = AudioSessionController(
      userWantsPlaying: () => _userWantsPlaying,
      isPlaying: () => _player.state.playing,
      onPauseRequested: _pause,
      onResumeRequested: play,
      onDuck: _volumeController.setDucking,
    );

    unawaited(_audioSessionController.setup());
    _setupListeners();
    _recoveryController.startListening();
    unawaited(_engineConfigurator.configure());
    unawaited(_restoreController.ensureReady());

    // Inizializza l'equalizzatore all'avvio in base alle impostazioni persistite
    final eqEnabled = _prefs.getBool('equalizerEnabled') ?? false;
    final eqGainsStr =
        _prefs.getStringList('equalizerGains') ??
        ['0.0', '0.0', '0.0', '0.0', '0.0'];
    final eqGains = eqGainsStr.map((s) => double.tryParse(s) ?? 0.0).toList();
    unawaited(
      _equalizerController.setEqualizer(enabled: eqEnabled, gains: eqGains),
    );
  }

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    await _castController.updateCastState(state, service);
  }

  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gains,
  }) async {
    await _equalizerController.setEqualizer(enabled: enabled, gains: gains);
  }

  /// Stream of [RestoreStatus] changes. [PlayerNotifier] subscribes here to
  /// drive the shimmer / loading UI and block interactive controls.
  Stream<RestoreStatus> get restoreStatusStream =>
      _restoreController.restoreStatusStream;

  /// The current restore status (synchronous read for initial state).
  RestoreStatus get currentRestoreStatus =>
      _restoreController.currentRestoreStatus;

  /// The playback position restored from disk.  Available as soon as
  /// [RestoreStatus.restoring] is emitted; used by [PlayerNotifier] to
  /// pre-populate the seek bar before the player has actually seeked.
  Duration get savedPosition => _restoreController.savedPosition;

  Stream<Duration?> get durationStream =>
      _player.stream.duration.map((d) => d == Duration.zero ? null : d);

  /// Exposes the raw position stream from media_kit so that UI layers can
  /// subscribe to it directly without going through [playbackState], which
  /// would cause Android Auto to re-render the queue view on every tick.
  Stream<Duration> get positionStream => _player.stream.position;

  void _setupListeners() {
    _player.stream.playing.listen((playing) {
      if (playing) {
        _userWantsPlaying = true;
      } else if (!_restoreController.isRestoring &&
          !_volumeController.isTransitionMuted &&
          !_castController.pausedForConnection) {
        _userWantsPlaying = false;
      }
      _statePublisher.updatePlaybackState();
    });
    _player.stream.buffering.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );
    _player.stream.completed.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );

    _player.stream.playlist.listen((playlist) {
      if (!_queueController.isResolvingItem) {
        _statePublisher.updatePlaybackState();
      }
      _onPlaylistChanged(playlist);
    });

    _player.stream.duration.listen((duration) {
      // Duration is independent of URL resolve; do not drop updates while
      // isResolvingItem (look-ahead) or AA seekbar stays at 0 forever when
      // media_kit emits duration only once during that window.
      if (duration == Duration.zero) return;

      // Resolve can suppress _onPlaylistChanged mediaItem updates across a
      // skip, so mediaItem.value may still be the previous track while the
      // player has already moved on. Bind duration to the playlist identity.
      final playlist = _player.state.playlist;
      final index = playlist.index;
      MediaItem? playingItem;
      if (index >= 0 && index < playlist.medias.length) {
        playingItem = playlist.medias[index].extras?['mediaItem'] as MediaItem?;
      }

      final current = mediaItem.value;
      final playingTrack =
          playingItem != null ? QueueTrack.fromMediaItem(playingItem) : null;
      final currentTrack =
          current != null ? QueueTrack.fromMediaItem(current) : null;

      if (playingTrack != null &&
          playingItem != null &&
          (currentTrack == null ||
              currentTrack.videoId != playingTrack.videoId)) {
        final updatedTrack =
            (playingTrack.duration != null &&
                    playingTrack.duration != Duration.zero)
                ? playingTrack
                : playingTrack.copyWith(duration: duration);
        final updated = updatedTrack.toMediaItem(playingItem);
        _statePublisher.noteEmittedMediaItem(updated, track: updatedTrack);
        mediaItem.add(updated);
        return;
      }

      if (current == null || currentTrack == null) return;
      if (currentTrack.duration != null &&
          currentTrack.duration != Duration.zero) {
        return;
      }
      final updatedTrack = currentTrack.copyWith(duration: duration);
      final updated = updatedTrack.toMediaItem(current);
      _statePublisher.noteEmittedMediaItem(updated, track: updatedTrack);
      mediaItem.add(updated);
    });

    _player.stream.position.listen((pos) {
      _volumeController.handleCrossfade(pos);
      _statePublisher.handlePositionTick(pos);
      if (_volumeController.isTransitionMuted &&
          _player.state.playing &&
          pos.inMilliseconds > 150) {
        _volumeController.endTransitionMute();
      }
    });
    _player.stream.buffer.listen(_statePublisher.onBufferedPositionChanged);

    _player.stream.shuffle.listen((shuffled) {
      final shuffleMode =
          shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
      _rebuildControls();
    });

    _player.stream.playlistMode.listen((mode) {
      final repeatMode = switch (mode) {
        PlaylistMode.none => AudioServiceRepeatMode.none,
        PlaylistMode.single => AudioServiceRepeatMode.one,
        PlaylistMode.loop => AudioServiceRepeatMode.all,
      };
      _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
      _rebuildControls();
    });
  }

  void _rebuildControls() {
    _statePublisher.updateState(
      (s) => s.copyWith(
        controls: PlayerMediaControls.build(
          s,
          isLiked: _likeController.isCurrentSongLiked,
        ),
      ),
    );
  }

  void _onPlaylistChanged(Playlist playlist) {
    if (_isStopping) return;

    final index = playlist.index;
    if (index >= 0 && index < playlist.medias.length) {
      unawaited(_externalAudio.attachForMedia(playlist.medias[index]));
    } else {
      unawaited(_externalAudio.attachForMedia(null));
    }

    if (!_queueController.isResolvingItem) {
      _skipNavigator.clearTarget();
      _statePublisher.updateState((s) => s.copyWith(queueIndex: index));
      if (index >= 0) {
        // Persist the raw index alongside the item's stable identity (its
        // videoId) in the SAME atomic QueueMeta row that the queue itself
        // is persisted to (see `QueueRepositoryImpl`). Doing this on every
        // track change — not just when the queue's structure changes (see
        // `persistQueue` calls below) — means the "where were we" pointer
        // can never lag behind the actually-playing track, which used to
        // cause resuming into a stale/wrong index after a process restart.
        final currentMediaItem =
            index < playlist.medias.length
                ? (playlist.medias[index].extras?['mediaItem'] as MediaItem?)
                : null;
        final videoId =
            currentMediaItem != null
                ? QueueTrack.fromMediaItem(currentMediaItem).videoId
                : null;
        unawaited(_queueRepo.persistCurrentIndex(index, videoId: videoId));
      }
    }

    if (!_queueController.isResolvingItem &&
        index >= 0 &&
        index < playlist.medias.length) {
      final media = playlist.medias[index];
      var item = media.extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        var track = QueueTrack.fromMediaItem(item);
        final playerDuration = _player.state.duration;
        final trackChanged =
            track.videoId != _statePublisher.lastEmittedMediaItemId;
        // On track change, player.state.duration is often still the *previous*
        // track's length — copying it here stamps a stale duration and then
        // blocks the real player duration patch (skipAlreadySet).
        if (!trackChanged &&
            (track.duration == null || track.duration == Duration.zero) &&
            playerDuration != Duration.zero) {
          track = track.copyWith(duration: playerDuration);
          item = track.toMediaItem(item);
        }

        final durationResolved =
            !trackChanged &&
            (_statePublisher.lastEmittedDuration == null ||
                _statePublisher.lastEmittedDuration == Duration.zero) &&
            (track.duration != null && track.duration != Duration.zero);
        if (trackChanged || durationResolved) {
          _statePublisher.noteEmittedMediaItem(item, track: track);
          mediaItem.add(item);
          if (trackChanged) {
            _recoveryController.resetRetryCount();
            _likeController.checkCurrentSongLiked(track.videoId);
            if (_castController.castState?.connectionState ==
                CastConnectionState.connected) {
              if (!track.needsUrl) {
                unawaited(
                  _castController
                      .castSong(
                        item,
                        _castController.castState!,
                        _castController.castService!,
                      )
                      .catchError(
                        (Object e) =>
                            dev.log('[AudioHandler] castSong error: $e'),
                      ),
                );
              }
            }
          }
        }
      }
    }

    unawaited(
      _urlResolver
          .resolvePendingItems(index)
          .catchError(
            (Object e) =>
                dev.log('[AudioHandler] _resolvePendingItems error: $e'),
          ),
    );

    if (!_queueController.isResolvingItem) {
      _queueController.syncQueue(isStopping: _isStopping);
    }

    if (!_queueController.isResolvingItem) {
      _volumeController.beginFadeIn();
    }
  }

  @override
  Future<void> play() async {
    _userWantsPlaying = true;
    _isStopping = false;
    _audioSessionController.cancelResumeOnInterruptionEnd();
    _restoreController.clearPauseTimestamp();

    if (!_player.state.playing) {
      _statePublisher.updateState(
        (s) => s.copyWith(processingState: AudioProcessingState.buffering),
      );
    }

    await _restoreController.awaitReady();

    if (await _audioSessionController.requestFocus()) {
      await _player.play();
      if (_castController.castState?.connectionState ==
          CastConnectionState.connected) {
        await _castController.castService?.play();
      }
    } else {
      _userWantsPlaying = false;
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
    }
  }

  /// AA/AAOS call this when the media source becomes active. Native audio_service
  /// activates the MediaSession first; we finish restore and publish paused
  /// metadata so the now-playing chrome appears without requiring a browse tap.
  @override
  Future<void> prepare() async {
    await _restoreController.awaitReady();
    final playlist = _player.state.playlist;
    final idx = playlist.index;
    if (mediaItem.valueOrNull == null &&
        idx >= 0 &&
        idx < playlist.medias.length) {
      final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        mediaItem.add(item);
      }
    }
    _statePublisher.invalidate();
    _statePublisher.updatePlaybackState();
  }

  void _notifyAndroidAutoResumption() {
    if (!isAndroid) return;
    unawaited(
      AudioServicePlatform.instance
          .notifyChildrenChanged(
            const NotifyChildrenChangedRequest(parentMediaId: 'recent'),
          )
          .catchError((Object e) {
            dev.log('[AA] notifyChildrenChanged(recent) failed: $e');
          }),
    );
  }

  @override
  Future<void> pause() async {
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _pause();
  }

  Future<void> _pause() async {
    _userWantsPlaying = false;
    _restoreController.markPaused();
    await _player.pause();
    if (_castController.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castController.castService?.pause();
    }
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _persistPlaybackPointer();
  }

  @override
  Future<void> stop() async {
    _userWantsPlaying = false;
    _restoreController.markPaused();
    if (_castController.castState?.connectionState ==
        CastConnectionState.connected) {
      try {
        await _castController.castService?.disconnect();
      } catch (_) {}
    }
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _persistPlaybackPointer();
    _isStopping = true;
    _urlResolver.cancelLookahead();
    _volumeController.endTransitionMute();
    await _player.stop();
    await _audioSessionController.releaseFocus();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _statePublisher.updateState((s) => s, forcePosition: position);
    if (_castController.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castController.castService?.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    await _restoreController.awaitReady();

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    final currentIndex = _player.state.playlist.index;
    final currentTarget = _skipNavigator.resolveCurrentTarget(
      currentIndex,
      len,
    );
    final shuffle =
        playbackState.value.shuffleMode == AudioServiceShuffleMode.all;
    final repeatAll =
        playbackState.value.repeatMode == AudioServiceRepeatMode.all ||
        playbackState.value.repeatMode == AudioServiceRepeatMode.group;
    final nextIndex = SkipNavigator.computeNextIndex(
      length: len,
      currentTarget: currentTarget,
      shuffle: shuffle,
      repeatAll: repeatAll,
    );

    _skipNavigator.targetSkipIndex = nextIndex;
    await skipToQueueItem(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    await _restoreController.awaitReady();

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    // Standard behavior: if we've played more than 3 seconds of the current track,
    // "skip previous" just restarts the current track.
    if (_player.state.position.inSeconds >= 3) {
      await seek(Duration.zero);
      return;
    }

    final currentIndex = _player.state.playlist.index;
    final currentTarget = _skipNavigator.resolveCurrentTarget(
      currentIndex,
      len,
    );
    final shuffle =
        playbackState.value.shuffleMode == AudioServiceShuffleMode.all;
    final repeatAll =
        playbackState.value.repeatMode == AudioServiceRepeatMode.all ||
        playbackState.value.repeatMode == AudioServiceRepeatMode.group;
    final historyIndex = shuffle ? _skipNavigator.popHistory() : null;
    final prevIndex = SkipNavigator.computePreviousIndex(
      length: len,
      currentTarget: currentTarget,
      shuffle: shuffle,
      repeatAll: repeatAll,
      historyIndex: historyIndex,
    );

    // If the calculated previous index is the same as the current one
    // (e.g. at the start of the queue with repeat-all off), just restart.
    if (prevIndex == currentIndex) {
      await seek(Duration.zero);
      return;
    }

    _skipNavigator.targetSkipIndex = prevIndex;
    _skipNavigator.beginBackward();
    try {
      await skipToQueueItem(prevIndex);
    } finally {
      _skipNavigator.endBackward();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _statePublisher.updateState(
      (s) => s.copyWith(processingState: AudioProcessingState.buffering),
    );

    await _restoreController.awaitReady();

    final playlist = _player.state.playlist;
    if (index < 0 || index >= playlist.medias.length) return;

    _volumeController.prepareTransitionMute();

    try {
      final currentIndex = playlist.index;
      if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all &&
          currentIndex >= 0 &&
          currentIndex != index &&
          !_skipNavigator.isGoingBackward) {
        _skipNavigator.recordForwardSkip(currentIndex);
      }

      final media = playlist.medias[index];
      final item = media.extras?['mediaItem'] as MediaItem?;
      final track = item != null ? QueueTrack.fromMediaItem(item) : null;

      if (track?.needsUrl == true) {
        await _urlResolver.resolveSinglePendingItem(
          index,
          treatAsCurrent: true,
        );

        // Verify the resolve actually produced a playable URL before
        // jumping. On failure (e.g. a transient network hiccup or a 429
        // that didn't recover in time), `_resolveSinglePendingItem` leaves
        // `needsUrl` untouched, and the underlying Media is still the
        // http://localhost dummy placeholder — jumping there would leave
        // playback silently "doing nothing" with zero feedback to the user.
        final refreshed = _player.state.playlist;
        final refreshedTrack =
            index < refreshed.medias.length
                ? QueueTrack.fromMediaItem(
                  refreshed.medias[index].extras?['mediaItem'] as MediaItem,
                )
                : null;
        if (refreshedTrack?.needsUrl == true) {
          _volumeController.endTransitionMute();
          // Resolve failed while playlist.index may still be the previous
          // track (treatAsCurrent resolve before jump), so the resolver's
          // onResolveFailed path may not run. Advance past this index and
          // emit a single PlayErrorEvent from advancePastUnplayable.
          await _recoveryController.advancePastUnplayable(
            index,
            videoId: track?.videoId ?? item?.id ?? '',
            title: item?.title ?? '',
            kind: _urlResolver.lastResolveFailureKind ?? PlayErrorKind.unknown,
          );
          return;
        }
      }

      await _player.jump(index);
      // If the user wanted playback but the player is still paused after the
      // jump (e.g., tap an item while paused), resume — but only when not in
      // cast mode, since castSong (fired from _onPlaylistChanged) owns resumption.
      if (_userWantsPlaying &&
          !_player.state.playing &&
          _castController.castState?.connectionState !=
              CastConnectionState.connected) {
        await play();
      }
    } catch (e) {
      _volumeController.endTransitionMute();
      rethrow;
    }
  }

  void setCrossfadeDuration(Duration duration) {
    _volumeController.setCrossfadeDuration(duration);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffle(enabled);
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _skipNavigator.clearHistory();
    }
    _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
    unawaited(_queueRepo.persistPlaybackModes(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final playlistMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => PlaylistMode.none,
      AudioServiceRepeatMode.one => PlaylistMode.single,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => PlaylistMode.loop,
    };
    await _player.setPlaylistMode(playlistMode);
    _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
    unawaited(_queueRepo.persistPlaybackModes(repeatMode: repeatMode));
  }

  // ── Queue getters (delegated to QueueController) ──────────────────────────

  /// Public read-only view of the current playlist, exposed for
  /// integrations (Android Auto, Cast) that need to inspect the queue
  /// without modifying it.
  List<MediaItem> get currentQueue => _queueController.currentQueue;

  /// User-queue portion of the current playlist (items not tagged as
  /// upnext). Single source of truth for the User/UpNext split used by
  /// the UI and Android Auto.
  List<MediaItem> get userQueue => _queueController.userQueue;

  /// Autoplay "Up Next" portion of the current playlist.
  List<MediaItem> get upNextQueue => _queueController.upNextQueue;

  // ── Queue section helpers (delegated to QueueController) ──────────────────

  static QueueSection sectionOf(MediaItem item) =>
      QueueController.sectionOf(item);

  static bool isUpNext(MediaItem item) => QueueController.isUpNext(item);

  Future<void> setQueue(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) async {
    _isStopping = false;
    _volumeController.prepareTransitionMute();
    await _synchronizedOpen(() async {
      _queueController.beginResolving();
      try {
        final (itemsWithKeys, medias) = _queueController.preparePlaylist(
          items,
          initialIndex: initialIndex,
        );
        queue.add(itemsWithKeys);
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
        _userWantsPlaying = false;
        await _player.open(playlist, play: false);
      } catch (e) {
        _volumeController.endTransitionMute();
        rethrow;
      } finally {
        _queueController.endResolving();
        if (!_queueController.isResolvingItem) {
          _statePublisher.invalidate();
          _statePublisher.updatePlaybackState();
        }
      }
    }, shouldAbort: shouldAbort);
  }

  Future<void> playNow(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) async {
    _isStopping = false;
    _volumeController.prepareTransitionMute();
    await _synchronizedOpen(() async {
      _queueController.beginResolving();
      try {
        final (itemsWithKeys, medias) = _queueController.preparePlaylist(
          items,
          initialIndex: initialIndex,
        );
        var resolvedItems = itemsWithKeys;
        queue.add(resolvedItems);
        // Same reasoning as setQueue: a brand-new session starts at 0.
        await _queueRepo.persistQueue(
          resolvedItems,
          currentIndex: initialIndex,
          position: Duration.zero,
        );

        if (initialIndex >= 0 && initialIndex < resolvedItems.length) {
          final initialItem = resolvedItems[initialIndex];
          final track = QueueTrack.fromMediaItem(initialItem);
          if (track.needsUrl) {
            try {
              final url = await _playVideoIdUseCase.resolveUrl(
                track.videoId,
                preferVideo: _queueController.prefersVideo(track),
              );
              final resolved = track
                  .copyWith(url: url, needsUrl: false)
                  .toMediaItem(initialItem);
              resolvedItems = List.from(resolvedItems);
              resolvedItems[initialIndex] = resolved;
              queue.add(resolvedItems);
              await _queueRepo.persistQueue(
                resolvedItems,
                currentIndex: initialIndex,
              );
            } catch (e) {
              dev.log(
                '[AudioHandler] Failed to resolve initial item URL for ${track.videoId}: $e',
              );
            }
          }
        }

        final finalMedias =
            resolvedItems.map(_queueController.toMedia).toList();
        final playlist = Playlist(finalMedias, index: initialIndex);
        final hasFocus = await _audioSessionController.requestFocus();
        _userWantsPlaying = hasFocus;
        await _player.open(playlist, play: hasFocus);
      } catch (e) {
        _volumeController.endTransitionMute();
        rethrow;
      } finally {
        _queueController.endResolving();
        if (!_queueController.isResolvingItem) {
          _statePublisher.invalidate();
          _statePublisher.updatePlaybackState();
        }
      }
    }, shouldAbort: shouldAbort);
  }

  Future<void> playNext(MediaItem item) async {
    await _queueController.runBatch(
      () => _queueController.playNext(item),
      isStopping: _isStopping,
      onSettled: () => _statePublisher.updatePlaybackState(),
    );
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _queueController.addToQueue(mediaItem);
  }

  Future<void> addToQueue(MediaItem item) async {
    await addQueueItem(item);
  }

  Future<void> addAllToQueue(List<MediaItem> items) async {
    if (items.isEmpty) return;
    await _queueController.runBatch(
      () => _queueController.addAllToQueue(items),
      isStopping: _isStopping,
      onSettled: () => _statePublisher.updatePlaybackState(),
    );
  }

  Future<void> appendUpNext(List<MediaItem> items) async {
    if (items.isEmpty) return;
    await _queueController.runBatch(
      () => _queueController.appendUpNext(items),
      isStopping: _isStopping,
      onSettled: () => _statePublisher.updatePlaybackState(),
    );
  }

  /// Removes every item currently tagged as [QueueSection.upnext] from the
  /// underlying media_kit playlist, leaving the user queue untouched.
  ///
  /// The current playback is preserved (if the current item itself is
  /// upnext, it is left in place to avoid a jarring skip).
  Future<void> _purgeUpNext() async {
    await _queueController.purgeUpNext();
  }

  /// Enables or disables autoplay. When [enabled] is `false`, the current
  /// "Up Next" section is purged from the playlist and the internal
  /// autoplay flag is flipped so subsequent refill attempts are skipped
  /// until the flag is turned back on.
  ///
  /// The flag is held in memory only (PlayerNotifier reads it through
  /// [Settings.autoPlayUpNext] on every refill trigger).
  Future<void> setAutoplayEnabled(bool enabled) async {
    if (!enabled) {
      await _purgeUpNext();
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await _queueController.removeAt(index);
  }

  Future<void> clearQueue() async {
    _userWantsPlaying = false;
    _urlResolver.cancelLookahead();
    await _queueController.clear();
    queue.add([]);
  }

  /// Removes every user-queue track (everything not tagged as
  /// [QueueSection.upnext]) from the underlying playlist, preserving the
  /// autoplay "Up Next" section.
  ///
  /// The currently playing track is always kept in place (mirroring
  /// [_purgeUpNext]) so a queue-clear action never interrupts playback.
  Future<void> purgeUserQueue() async {
    await _queueController.purgeUserQueue();
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final len = _player.state.playlist.medias.length;

    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;
    if (oldIndex == newIndex) return;

    // A queue reorder shifts indices; invalidate the pending skip target so
    // the next skipToNext/Prev computes the correct index from scratch.
    _skipNavigator.clearTarget();

    // Guard with resolving state so _onPlaylistChanged suppresses
    // intermediate queue syncs during the move + possible retag.
    await _queueController.runBatch(
      () => _queueController.move(oldIndex, newIndex),
      isStopping: _isStopping,
      onSettled: () => _statePublisher.updatePlaybackState(),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    _restoreController.markPaused();
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _persistPlaybackPointer();
    _isStopping = true;
    await _player.stop();
    await _audioSessionController.releaseFocus();
    await super.onTaskRemoved();
  }

  Future<void> persistQueue(List<MediaItem> items) async {
    await _queueRepo.persistQueue(
      items,
      currentIndex: _player.state.playlist.index,
      shuffleMode: playbackState.value.shuffleMode,
      repeatMode: playbackState.value.repeatMode,
    );
  }

  Future<void> restoreIfNeeded() => _restoreController.ensureReady();

  void dispose() {
    _isStopping = true;
    _urlResolver.cancelLookahead();
    _urlResolver.dispose();
    _recoveryController.dispose();
    _audioSessionController.dispose();
    _restoreController.dispose();
    _player.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — getChildren (AA browse tree)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) {
    return _browserController.getChildren(parentMediaId, options);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromMediaId
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) {
    return _browserController.playFromMediaId(mediaId, extras);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — search
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) {
    return _browserController.search(query, extras);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromSearch
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) {
    return _browserController.playFromSearch(query, extras);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — setRating
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    if (!rating.hasHeart()) return;
    _likeController.toggleOptimistic();
    try {
      final current =
          _queueController.currentQueue
              .where((item) => item.id == mediaItem.value?.id)
              .firstOrNull;
      final videoId = current?.id ?? (mediaItem.value?.id ?? '');
      final track = current != null ? QueueTrack.fromMediaItem(current) : null;
      await _likeController.toggleLikedSong(
        LikedSongModel(
          videoId: videoId,
          title: current?.title ?? 'Unknown',
          artist: current?.artist ?? 'Unknown Artist',
          thumbnailUrl: current?.artUri?.toString(),
          addedAt: DateTime.now(),
          duration: current?.duration?.inSeconds,
          isVideo: track?.isVideo ?? false,
          isExplicit: track?.isExplicit ?? false,
        ),
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — customAction
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case PlayerMediaControls.actionShuffle:
        final current = playbackState.value.shuffleMode;
        final next =
            current == AudioServiceShuffleMode.none
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none;
        await setShuffleMode(next);
        break;

      case PlayerMediaControls.actionRepeat:
        const modes = [
          AudioServiceRepeatMode.none,
          AudioServiceRepeatMode.all,
          AudioServiceRepeatMode.one,
        ];
        final current = playbackState.value.repeatMode;
        final idx = modes.indexOf(current);
        final next = modes[(idx + 1) % modes.length];
        await setRepeatMode(next);
        break;

      case PlayerMediaControls.actionLike:
        final item = mediaItem.value;
        if (item == null) return null;
        _likeController.toggleOptimistic();
        final track = QueueTrack.fromMediaItem(item);
        await _likeController.toggleLikedSong(
          LikedSongModel(
            videoId: item.id,
            title: item.title,
            artist: item.artist ?? 'Unknown Artist',
            thumbnailUrl: item.artUri?.toString(),
            addedAt: DateTime.now(),
            duration: item.duration?.inSeconds,
            isVideo: track.isVideo,
            isExplicit: track.isExplicit,
          ),
        );
        break;

      case PlayerMediaControls.actionStartRadio:
        final item = mediaItem.value;
        if (item != null) {
          await startRadio(item.id);
        }
        break;
    }
    return null;
  }

  Future<void> startRadio(String videoId) async {
    try {
      final result = await _startRadioUseCase.execute(videoId);
      final firstItem = result.firstItem;
      final remaining = _startRadioUseCase.toPendingItems(result.remaining);
      await playNow([firstItem, ...remaining]);
    } catch (e, st) {
      dev.log('[AA] Failed to start radio for videoId $videoId: $e\n$st');
    }
  }
}
