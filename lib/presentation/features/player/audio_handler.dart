import 'dart:async';
import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'just_audio_playback_engine.dart';
import 'playback_engine.dart';
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
import 'player_media_controls.dart';
import 'playback_intent_controller.dart';
import 'playback_recovery_controller.dart';
import 'playback_restore_controller.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'playlist_open_coordinator.dart';
import 'queue_controller.dart';
import 'skip_navigator.dart';
import 'track_transition_coordinator.dart';
import 'track_url_resolver.dart';

export 'playback_restore_controller.dart' show RestoreStatus;
export 'play_error.dart' show PlayErrorEvent, PlayErrorKind;

import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/models/media_quality.dart';
import '../../providers/settings_provider.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final JustAudioPlaybackEngine _engine = JustAudioPlaybackEngine.create();
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
  late final LikeController _likeController;
  late final PlaybackVolumeController _volumeController;
  late final PlaybackStatePublisher _statePublisher;
  late final SkipNavigator _skipNavigator;
  late final TrackUrlResolver _urlResolver;
  late final PlaybackRecoveryController _recoveryController;
  late final PlaybackRestoreController _restoreController;
  late final ExternalAudioTrackController _externalAudio;
  late final PlaylistOpenCoordinator _playlistOpener;
  late final TrackTransitionCoordinator _transitions;

  final _uiPosition = StreamController<Duration>.broadcast();
  final _uiDuration = StreamController<Duration?>.broadcast();
  StreamSubscription<Duration>? _engineUiPosSub;
  StreamSubscription<Duration>? _engineUiDurSub;

  /// Single [Connectivity] instance shared across the entire player module.
  /// Avoids multiple platform-channel registrations for the same signal.
  static final Connectivity _sharedConnectivity = Connectivity();

  PlaybackEngine get engine => _engine;

  /// Syncs stream quality prefs used when building proxy URLs.
  /// Rebuilds in-memory sources when quality actually changes so the current
  /// playlist picks up new proxy URLs.
  void updateStreamPrefs({MediaQuality? streamAudioQuality}) {
    final audioChanged =
        streamAudioQuality != null &&
        streamAudioQuality != _queueController.streamAudioQuality;
    _queueController.updateStreamPrefs(streamAudioQuality: streamAudioQuality);
    if (audioChanged) {
      unawaited(_playlistOpener.rebuildMedia());
    }
  }

  Future<void> _persistPlaybackPointer() async {
    // During cold restore, media_kit seek is async: endResolving used to
    // persist position 0 and wipe the just-restored pointer before seek landed.
    if (_restoreController.isRestoring) return;

    final playlist = _engine.state.playlist;
    final index = playlist.index;
    if (index < 0) return;
    String? videoId;
    if (index < playlist.medias.length) {
      final item = playlist.medias[index].mediaItem;
      if (item != null) {
        videoId = QueueTrack.fromMediaItem(item).videoId;
      }
    }
    await _queueRepo.persistPlaybackPointer(
      currentIndex: index,
      videoId: videoId,
      position:
          _isCastConnected()
              ? (_castController.lastCastPosition ?? _engine.state.position)
              : _engine.state.position,
    );
  }

  bool _isStopping = false;

  /// What the user wants playback to be doing, as opposed to what the engine is
  /// doing. See [PlaybackIntentController] for the full truth table.
  final PlaybackIntentController _intent = PlaybackIntentController();

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
    _externalAudio = ExternalAudioTrackController(engine: _engine);
    _startRadioUseCase = StartRadioUseCase(musicRepo);

    _likeController = LikeController(
      libraryRepo: libraryRepo,
      onLikeChanged: () => _transitions.rebuildControls(),
    );

    _equalizerController = EqualizerController(
      equalizer: _engine.androidEqualizer,
    );

    _queueController = QueueController(
      engine: _engine,
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

    // Volume must be constructed before cast so CastPlaybackController can
    // receive it; isCastConnected is late-bound and safe once cast is assigned.
    _volumeController = PlaybackVolumeController(
      engine: _engine,
      isCastConnected:
          () =>
              _castController.castState?.connectionState ==
              CastConnectionState.connected,
    );
    _castController = CastPlaybackController(
      engine: _engine,
      volumeController: _volumeController,
      playVideoIdUseCase: _playVideoIdUseCase,
      userWantsPlaying: () => _intent.userWantsPlaying,
      currentMediaItem: () => mediaItem.value,
      lanCastUrl: _queueController.lanCastUrlFor,
    );
    _statePublisher = PlaybackStatePublisher(
      engine: _engine,
      getPlaybackState: () => playbackState.value,
      setPlaybackState: (state) => playbackState.add(state),
      isRestoring: () => _restoreController.isRestoring,
      isResolving: () => _queueController.isResolvingItem,
      savedPosition: () => _restoreController.savedPosition,
      isLiked: () => _likeController.isCurrentSongLiked,
      isExplicitlyPaused: () => _intent.isExplicitlyPaused,
      onBecameReady: () => _recoveryController.resetRetryCount(),
      isCastConnected: _isCastConnected,
      isCastSessionPlaying: () => _castController.isRemotePlaying,
      castPosition: () => _castController.lastCastPosition,
    );
    _castController.onTransportChanged = _onCastTransportChanged;
    _castController.onCastPosition = _onCastPosition;
    _castController.onCastDuration = _onCastDuration;
    _skipNavigator = SkipNavigator();
    _urlResolver = TrackUrlResolver(
      engine: _engine,
      playVideoIdUseCase: _playVideoIdUseCase,
      queueController: _queueController,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      isCastConnected:
          () =>
              _castController.castState?.connectionState ==
              CastConnectionState.connected,
      userWantsPlaying: () => _intent.userWantsPlaying,
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
          () async {
            await _castController.waitForCastSessionState(
              _castController.castService!,
              SessionState.playing,
            );
          },
      castPause: () async {
        await _castController.castService?.pause();
      },
    );
    _recoveryController = PlaybackRecoveryController(
      engine: _engine,
      playVideoIdUseCase: _playVideoIdUseCase,
      queueController: _queueController,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      urlResolver: _urlResolver,
      connectivity: _sharedConnectivity,
      userWantsPlaying: () => _intent.userWantsPlaying,
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
          () async {
            await _castController.waitForCastSessionState(
              _castController.castService!,
              SessionState.playing,
            );
          },
      castPause: () async {
        await _castController.castService?.pause();
      },
    );
    _restoreController = PlaybackRestoreController(
      engine: _engine,
      prefs: _prefs,
      queueRepo: _queueRepo,
      queueController: _queueController,
      urlResolver: _urlResolver,
      statePublisher: _statePublisher,
      playVideoIdUseCase: _playVideoIdUseCase,
      setUserWantsPlaying: _intent.setUserWantsPlaying,
      emitMediaItem: (item) => mediaItem.add(item),
      applyShuffleMode: (shuffleMode) async {
        await _engine.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
        _statePublisher.updateState(
          (s) => s.copyWith(shuffleMode: shuffleMode),
        );
      },
      applyRepeatMode: (repeatMode) async {
        final engineRepeat = switch (repeatMode) {
          AudioServiceRepeatMode.none => EngineRepeatMode.none,
          AudioServiceRepeatMode.one => EngineRepeatMode.one,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => EngineRepeatMode.all,
        };
        await _engine.setRepeatMode(engineRepeat);
        _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
      },
      updateQueueStream: (items) => queue.add(items),
      setIsStopping: (v) => _isStopping = v,
      onRestoreReady: _notifyAndroidAutoResumption,
    );
    _audioSessionController = AudioSessionController(
      userWantsPlaying: () => _intent.userWantsPlaying,
      isPlaying: () => _engine.state.playing,
      onPauseRequested: _pause,
      onResumeRequested: play,
      onDuck: _volumeController.setDucking,
    );
    _playlistOpener = PlaylistOpenCoordinator(
      engine: _engine,
      queueController: _queueController,
      queueRepo: _queueRepo,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      intent: _intent,
      playVideoIdUseCase: _playVideoIdUseCase,
      requestFocus: _audioSessionController.requestFocus,
      emitQueue: (items) => queue.add(items),
      isStopping: () => _isStopping,
      setIsStopping: (v) => _isStopping = v,
      log: dev.log,
    );
    _transitions = TrackTransitionCoordinator(
      engine: _engine,
      intent: _intent,
      externalAudio: _externalAudio,
      queueController: _queueController,
      skipNavigator: _skipNavigator,
      statePublisher: _statePublisher,
      queueRepo: _queueRepo,
      recoveryController: () => _recoveryController,
      likeController: _likeController,
      castController: () => _castController,
      urlResolver: _urlResolver,
      volumeController: _volumeController,
      currentMediaItem: () => mediaItem.value,
      emitMediaItem: (item) => mediaItem.add(item),
      isStopping: () => _isStopping,
      isRestoring: () => _restoreController.isRestoring,
      isShuffleAll:
          () => playbackState.value.shuffleMode == AudioServiceShuffleMode.all,
      isRepeatOne:
          () => playbackState.value.repeatMode == AudioServiceRepeatMode.one,
      skipToNext: skipToNext,
      skipToQueueItem: skipToQueueItem,
    );

    unawaited(_audioSessionController.setup());
    _transitions.setupListeners();
    _recoveryController.startListening();
    _engineUiPosSub = _engine.positionStream.listen((pos) {
      if (_isCastConnected()) return;
      if (!_uiPosition.isClosed) _uiPosition.add(pos);
    });
    _engineUiDurSub = _engine.durationStream.listen((d) {
      if (_isCastConnected()) return;
      if (!_uiDuration.isClosed) {
        _uiDuration.add(d == Duration.zero ? null : d);
      }
    });
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

  bool _isCastConnected() =>
      _castController.castState?.connectionState ==
      CastConnectionState.connected;

  void _onCastTransportChanged() {
    if (_isCastConnected()) {
      final remote = _castController.remoteSessionState;
      if (remote == SessionState.playing) {
        _intent.onPlayAccepted();
      } else if (remote == SessionState.paused) {
        _intent.onPauseApplied();
      }
    }
    _statePublisher.invalidate();
    _statePublisher.updatePlaybackState();
  }

  void _onCastPosition(Duration pos) {
    if (!_uiPosition.isClosed) _uiPosition.add(pos);
    _statePublisher.handlePositionTick(pos);
  }

  void _onCastDuration(Duration d) {
    if (d > Duration.zero && !_uiDuration.isClosed) {
      _uiDuration.add(d);
    }
  }

  Stream<Duration?> get durationStream => _uiDuration.stream;

  Stream<Duration> get positionStream => _uiPosition.stream;

  /// In-app / deliberate resume entry point. Bypasses the guard that blocks
  /// spurious MediaSession PLAY after Pixel Buds ear-detection while paused.
  Future<void> resumeFromUser() => _intent.runAuthorizedResume(play);

  /// In-app pause. Marks an explicit pause so ear-detection PLAY is
  /// ignored until [resumeFromUser]. MediaSession [pause] does not set this.
  Future<void> pauseFromUser() async {
    _intent.onUserPause();
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _pause();
    await _audioSessionController.releaseFocus();
    _statePublisher.invalidate();
    _statePublisher.updatePlaybackState();
  }

  @override
  Future<void> play() async {
    if (_intent.shouldRejectPlay(engineIsPlaying: _engine.state.playing)) {
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
      return;
    }
    _intent.onPlayAccepted();
    _isStopping = false;
    _audioSessionController.cancelResumeOnInterruptionEnd();
    _restoreController.clearPauseTimestamp();

    if (!_engine.state.playing) {
      _statePublisher.updateState(
        (s) => s.copyWith(processingState: AudioProcessingState.buffering),
      );
    }

    await _restoreController.awaitReady();

    if (await _audioSessionController.requestFocus()) {
      final castConnected =
          _castController.castState?.connectionState ==
          CastConnectionState.connected;
      if (castConnected) {
        await _castController.castService?.play();
      } else {
        await _engine.play();
      }
    } else {
      _intent.onFocusDenied();
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
    final playlist = _engine.state.playlist;
    final idx = playlist.index;
    if (mediaItem.valueOrNull == null &&
        idx >= 0 &&
        idx < playlist.medias.length) {
      final item = playlist.medias[idx].mediaItem;
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
    // MediaSession / buds / notification pause — deliberately not an explicit
    // pause, so a following buds tap can call [play].
    _intent.onSessionPause();
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _pause();
    await _audioSessionController.releaseFocus();
    _statePublisher.invalidate();
    _statePublisher.updatePlaybackState();
  }

  Future<void> _pause() async {
    _intent.onPauseApplied();
    _restoreController.markPaused();
    await _engine.pause();
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
    _intent.onStop();
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
    await _engine.stop();
    await _audioSessionController.releaseFocus();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    _statePublisher.updateState((s) => s, forcePosition: position);
    if (_castController.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castController.castService?.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    await _restoreController.awaitReady();

    final len = _engine.state.playlist.medias.length;
    if (len == 0) return;

    final currentIndex = _engine.state.playlist.index;
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

    final len = _engine.state.playlist.medias.length;
    if (len == 0) return;

    // Standard behavior: if we've played more than 3 seconds of the current track,
    // "skip previous" just restarts the current track.
    if (_engine.state.position.inSeconds >= 3) {
      await seek(Duration.zero);
      return;
    }

    final currentIndex = _engine.state.playlist.index;
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
    await _restoreController.awaitReady();

    final playlist = _engine.state.playlist;
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
      final item = media.mediaItem;
      final track = item != null ? QueueTrack.fromMediaItem(item) : null;
      // Proxy/file URIs are already playable even when extras still say
      // needsUrl. Waiting on YouTube resolve here is what made shuffled
      // skips take 1–2s — lookahead only prefetches sequential +1/+2/+3.
      final mustResolveBeforeJump =
          track?.needsUrl == true && isPlaceholderAudioUri(media.uri);

      if (mustResolveBeforeJump) {
        _statePublisher.updateState(
          (s) => s.copyWith(processingState: AudioProcessingState.buffering),
        );
        await _urlResolver.resolveSinglePendingItem(
          index,
          treatAsCurrent: true,
        );

        // Verify the resolve actually produced a playable URI before
        // jumping. On failure the engine is still on the dummy placeholder —
        // jumping there would leave playback silently doing nothing.
        final refreshed = _engine.state.playlist;
        final refreshedMedia =
            index < refreshed.medias.length ? refreshed.medias[index] : null;
        if (refreshedMedia == null ||
            isPlaceholderAudioUri(refreshedMedia.uri)) {
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

      await _engine.jump(index);
      // If the user wanted playback but the player is still paused after the
      // jump (e.g., tap an item while paused), resume — but only when not in
      // cast mode, since castSong (fired from _onPlaylistChanged) owns resumption.
      if (_intent.userWantsPlaying &&
          !_engine.state.playing &&
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
    await _engine.setShuffle(enabled);
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _skipNavigator.clearHistory();
    }
    _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
    unawaited(_queueRepo.persistPlaybackModes(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final engineRepeat = switch (repeatMode) {
      AudioServiceRepeatMode.none => EngineRepeatMode.none,
      AudioServiceRepeatMode.one => EngineRepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => EngineRepeatMode.all,
    };
    await _engine.setRepeatMode(engineRepeat);
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
  }) {
    _urlResolver.resetSession();
    return _playlistOpener.setQueue(
      items,
      initialIndex: initialIndex,
      shouldAbort: shouldAbort,
    );
  }

  Future<void> playNow(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) {
    _urlResolver.resetSession();
    return _playlistOpener.playNow(
      items,
      initialIndex: initialIndex,
      shouldAbort: shouldAbort,
    );
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
    _intent.onQueueCleared();
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
    final len = _engine.state.playlist.medias.length;

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
    await _engine.stop();
    await _audioSessionController.releaseFocus();
    await super.onTaskRemoved();
  }

  Future<void> persistQueue(List<MediaItem> items) async {
    await _queueRepo.persistQueue(
      items,
      currentIndex: _engine.state.playlist.index,
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
    unawaited(_engineUiPosSub?.cancel());
    unawaited(_engineUiDurSub?.cancel());
    unawaited(_uiPosition.close());
    unawaited(_uiDuration.close());
    _engine.dispose();
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
