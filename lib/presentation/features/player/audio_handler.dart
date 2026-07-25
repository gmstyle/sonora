import 'dart:async';
import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/url_staleness.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/utils/connectivity_utils.dart';
import '../../../data/services/media_cache_service.dart';
import '../../../data/services/local_audio_proxy_server.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';

import 'package:dart_cast/dart_cast.dart';
import '../../providers/cast_provider.dart';
import '../../../data/services/cast_service.dart';

import 'audio_cast_handler.dart';
import 'audio_android_auto_browser_handler.dart';
import 'audio_equalizer_handler.dart';
import 'audio_session_controller.dart';
import 'like_controller.dart';
import 'player_engine_configurator.dart';
import 'player_media_controls.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'queue_controller.dart';
import 'skip_navigator.dart';
import 'track_url_resolver.dart';

import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../providers/settings_provider.dart';

/// Represents the lifecycle of the player restore operation.
///
/// The UI observes this via [SonoraAudioHandler.restoreStatusStream] to decide
/// whether to show a loading indicator and block interactive controls.
enum RestoreStatus {
  /// No restore has been performed yet (initial state at startup).
  idle,

  /// A restore is in progress. The player is being rebuilt from the persisted
  /// queue. All interactive controls (play, pause, seek, skip) must be blocked.
  restoring,

  /// The player is ready. The current item has a valid URL, the seek position
  /// has been applied, and the user can interact normally.
  ready,
}

class SonoraAudioHandler extends BaseAudioHandler {
  final Player _player = Player(
    configuration: const PlayerConfiguration(pitch: true),
  );
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  final LocalAudioProxyServer? _proxyServer;
  late final StartRadioUseCase _startRadioUseCase;

  late final AudioCastHandler _castHandler;
  late final AudioAndroidAutoBrowserHandler _browserHandler;
  late final AudioEqualizerHandler _equalizerHandler;
  late final QueueController _queueController;
  late final AudioSessionController _audioSessionController;
  late final PlayerEngineConfigurator _engineConfigurator;
  late final LikeController _likeController;
  late final PlaybackVolumeController _volumeController;
  late final PlaybackStatePublisher _statePublisher;
  late final SkipNavigator _skipNavigator;
  late final TrackUrlResolver _urlResolver;

  /// Single [Connectivity] instance shared across the entire player module.
  /// Avoids multiple platform-channel registrations for the same signal.
  static final Connectivity _sharedConnectivity = Connectivity();

  Player get player => _player;
  LocalAudioProxyServer? get proxyServer => _proxyServer;

  int _retryCount = 0;
  bool _isRetrying = false;
  // Tracks the videoId of the last retried track so we can reset _retryCount
  // when a new track errors, even if _onPlaylistChanged's reset was suppressed
  // by _queueController.isResolvingItem being true during a concurrent URL resolution.
  String? _lastRetriedVideoId;
  bool _isStopping = false;
  StreamSubscription<String>? _playerErrorSub;
  bool _userWantsPlaying = false;
  bool _interruptedByNetworkDrop = false;
  DateTime? _lastPauseTimestamp;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void>? _playlistOpenLock;

  /// Serializes calls that rebuild the underlying media_kit playlist
  /// (setQueue / playNow). Actions run one at a time, in call order.
  ///
  /// When [shouldAbort] is provided it is evaluated right before the
  /// action runs (i.e. after any in-flight action completes); if it
  /// returns `true` the action is skipped entirely, so an obsolete caller
  /// never touches the player — the most recent call always wins.
  Future<void> _synchronizedOpen(
    Future<void> Function() action, {
    bool Function()? shouldAbort,
  }) async {
    final previous = _playlistOpenLock;
    final completer = Completer<void>();
    _playlistOpenLock = completer.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    try {
      if (shouldAbort?.call() ?? false) return;
      await action();
    } finally {
      completer.complete();
      // Only clear the lock if no newer call already replaced it.
      if (identical(_playlistOpenLock, completer.future)) {
        _playlistOpenLock = null;
      }
    }
  }

  // ── Restore state ──────────────────────────────────────────────────────────
  RestoreStatus _restoreStatus = RestoreStatus.idle;
  final StreamController<RestoreStatus> _restoreStatusController =
      StreamController<RestoreStatus>.broadcast();

  /// Completer that is uncompleted while [_restoreStatus] is [RestoreStatus.restoring].
  /// [play()] awaits this so that a notification/MPRIS play command issued
  /// during a restore does not race with the playlist rebuild.
  Completer<void> _readyCompleter = Completer<void>()..complete();

  /// The playback position read from SharedPreferences at restore time.
  /// Exposed so [PlayerNotifier] can pre-populate the seek bar immediately,
  /// before the player has actually seeked.
  Duration _savedPosition = Duration.zero;

  final StreamController<(String videoId, String title)>
  _onPlayErrorController =
      StreamController<(String videoId, String title)>.broadcast();

  Stream<(String videoId, String title)> get onPlayError =>
      _onPlayErrorController.stream;

  // Expose internals for delegate handlers
  double get lastSetVolume => _volumeController.lastSetVolume;
  bool get userWantsPlaying => _userWantsPlaying;
  PlayVideoIdUseCase get playVideoIdUseCase => _playVideoIdUseCase;

  void setLocalVolume(double volume, {bool force = false}) =>
      _volumeController.setLocalVolume(volume, force: force);

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
    _startRadioUseCase = StartRadioUseCase(musicRepo);

    _likeController = LikeController(
      libraryRepo: libraryRepo,
      onLikeChanged: () => _rebuildControls(),
    );

    _castHandler = AudioCastHandler(this);
    _browserHandler = AudioAndroidAutoBrowserHandler(
      audioHandler: this,
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
      connectivity: _sharedConnectivity,
    );

    _equalizerHandler = AudioEqualizerHandler(this);

    _queueController = QueueController(
      player: _player,
      queueRepo: _queueRepo,
      getQueue: () => queue.value,
      getShuffleMode: () => playbackState.value.shuffleMode,
      getRepeatMode: () => playbackState.value.repeatMode,
      updateQueueStream: (items) => queue.add(items),
      proxyServer: _proxyServer,
    );

    _engineConfigurator = PlayerEngineConfigurator(player: _player);
    _volumeController = PlaybackVolumeController(
      player: _player,
      isCastConnected:
          () =>
              _castHandler.castState?.connectionState ==
              CastConnectionState.connected,
    );
    _statePublisher = PlaybackStatePublisher(
      player: _player,
      getPlaybackState: () => playbackState.value,
      setPlaybackState: (state) => playbackState.add(state),
      isRestoring: () => _restoreStatus == RestoreStatus.restoring,
      savedPosition: () => _savedPosition,
      isLiked: () => _likeController.isCurrentSongLiked,
      onBecameReady: () => _retryCount = 0,
    );
    _skipNavigator = SkipNavigator();
    _urlResolver = TrackUrlResolver(
      player: _player,
      playVideoIdUseCase: _playVideoIdUseCase,
      queueController: _queueController,
      volumeController: _volumeController,
      statePublisher: _statePublisher,
      isCastConnected:
          () =>
              _castHandler.castState?.connectionState ==
              CastConnectionState.connected,
      userWantsPlaying: () => _userWantsPlaying,
      isStopping: () => _isStopping,
      requestPlay: play,
      onResolveFailed: _handlePlaybackConnectionFailure,
      emitMediaItem: (item) => mediaItem.add(item),
      setPausedForConnection: (v) => _castHandler.pausedForConnection = v,
      castMedia: ({
        required String url,
        required String title,
        String? artist,
        String? album,
        String? artworkUrl,
      }) async {
        await _castHandler.castService?.castMedia(
          url: url,
          title: title,
          artist: artist,
          album: album,
          artworkUrl: artworkUrl,
        );
      },
      waitForCastPlaying: () => _castHandler.waitForCastSessionState(
        _castHandler.castService!,
        SessionState.playing,
      ),
      castPause: () async {
        await _castHandler.castService?.pause();
      },
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
    _playerErrorSub = _player.stream.error.listen(_onPlayerError);
    _connectivitySub = _sharedConnectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    unawaited(_engineConfigurator.configure());
    unawaited(_ensureReady());

    // Inizializza l'equalizzatore all'avvio in base alle impostazioni persistite
    final eqEnabled = _prefs.getBool('equalizerEnabled') ?? false;
    final eqGainsStr =
        _prefs.getStringList('equalizerGains') ??
        ['0.0', '0.0', '0.0', '0.0', '0.0'];
    final eqGains = eqGainsStr.map((s) => double.tryParse(s) ?? 0.0).toList();
    unawaited(
      _equalizerHandler.setEqualizer(enabled: eqEnabled, gains: eqGains),
    );
  }

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    await _castHandler.updateCastState(state, service);
  }

  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gains,
  }) async {
    await _equalizerHandler.setEqualizer(enabled: enabled, gains: gains);
  }

  /// Stream of [RestoreStatus] changes. [PlayerNotifier] subscribes here to
  /// drive the shimmer / loading UI and block interactive controls.
  Stream<RestoreStatus> get restoreStatusStream =>
      _restoreStatusController.stream;

  /// The current restore status (synchronous read for initial state).
  RestoreStatus get currentRestoreStatus => _restoreStatus;

  /// The playback position restored from disk.  Available as soon as
  /// [RestoreStatus.restoring] is emitted; used by [PlayerNotifier] to
  /// pre-populate the seek bar before the player has actually seeked.
  Duration get savedPosition => _savedPosition;

  Stream<Duration?> get durationStream =>
      _player.stream.duration.map((d) => d == Duration.zero ? null : d);

  /// Exposes the raw position stream from media_kit so that UI layers can
  /// subscribe to it directly without going through [playbackState], which
  /// would cause Android Auto to re-render the queue view on every tick.
  Stream<Duration> get positionStream => _player.stream.position;

  void _setRestoreStatus(RestoreStatus status) {
    _restoreStatus = status;
    if (!_restoreStatusController.isClosed) {
      _restoreStatusController.add(status);
    }
    if (status == RestoreStatus.restoring) {
      // Create a fresh completer so play() blocks until restore completes.
      if (_readyCompleter.isCompleted) {
        _readyCompleter = Completer<void>();
      }
    } else {
      // ready or idle — unblock any awaiting play() call.
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  void _setupListeners() {
    _player.stream.playing.listen((playing) {
      if (playing) {
        _userWantsPlaying = true;
      } else if (_restoreStatus != RestoreStatus.restoring &&
          !_volumeController.isTransitionMuted &&
          !_castHandler.pausedForConnection) {
        _userWantsPlaying = false;
      }
      _statePublisher.updatePlaybackState();
    });
    _player.stream.buffering.listen((_) => _statePublisher.updatePlaybackState());
    _player.stream.completed.listen((_) => _statePublisher.updatePlaybackState());

    _player.stream.playlist.listen((playlist) {
      if (!_queueController.isResolvingItem) _statePublisher.updatePlaybackState();
      _onPlaylistChanged(playlist);
    });

    _player.stream.duration.listen((duration) {
      if (duration == Duration.zero || _queueController.isResolvingItem) return;
      final current = mediaItem.value;
      if (current == null) return;
      if (current.duration != null && current.duration != Duration.zero) return;
      final updated = current.copyWith(duration: duration);
      _statePublisher.lastEmittedDuration = duration;
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
        unawaited(
          _queueRepo.persistCurrentIndex(index, videoId: currentMediaItem?.id),
        );
      }
    }

    if (!_queueController.isResolvingItem &&
        index >= 0 &&
        index < playlist.medias.length) {
      final media = playlist.medias[index];
      var item = media.extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        final playerDuration = _player.state.duration;
        if ((item.duration == null || item.duration == Duration.zero) &&
            playerDuration != Duration.zero) {
          item = item.copyWith(duration: playerDuration);
        }

        final trackChanged = item.id != _statePublisher.lastEmittedMediaItemId;
        final durationResolved =
            !trackChanged &&
            (_statePublisher.lastEmittedDuration == null ||
                _statePublisher.lastEmittedDuration == Duration.zero) &&
            (item.duration != null && item.duration != Duration.zero);
        if (trackChanged || durationResolved) {
          _statePublisher.noteEmittedMediaItem(item);
          mediaItem.add(item);
          if (trackChanged) {
            _retryCount = 0;
            _likeController.checkCurrentSongLiked(item.id);
            if (_castHandler.castState?.connectionState ==
                CastConnectionState.connected) {
              if (!QueueTrack.fromMediaItem(item).needsUrl) {
                unawaited(
                  _castHandler
                      .castSong(
                        item,
                        _castHandler.castState!,
                        _castHandler.castService!,
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
      _urlResolver.resolvePendingItems(index).catchError(
        (Object e) => dev.log('[AudioHandler] _resolvePendingItems error: $e'),
      ),
    );

    if (!_queueController.isResolvingItem) {
      _queueController.syncQueue(isStopping: _isStopping);
    }

    if (!_queueController.isResolvingItem) {
      _volumeController.beginFadeIn();
    }
  }

  Future<void> _handlePlaybackConnectionFailure(
    String videoId,
    String title,
  ) async {
    _interruptedByNetworkDrop = true;
    final playlist = _player.state.playlist;
    final currentIndex = playlist.index;
    if (currentIndex < 0) return;

    // Scan remaining queue for a playable offline/cached track
    int targetIndex = -1;
    for (int i = currentIndex + 1; i < playlist.medias.length; i++) {
      final mediaItem = playlist.medias[i].extras?['mediaItem'] as MediaItem?;
      if (mediaItem == null) continue;
      final track = QueueTrack.fromMediaItem(mediaItem);

      bool isCached = false;
      final cachedUri = await MediaCacheService.instance.getCachedFileUri(
        track.videoId,
      );
      isCached = cachedUri != null;

      if (track.isLocalFile || isCached || !track.needsUrl) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1) {
      dev.log(
        '[AudioHandler] Connection failed. Advancing queue index to offline track at $targetIndex.',
      );
      await skipToQueueItem(targetIndex);
    } else {
      dev.log(
        '[AudioHandler] Connection failed and no offline tracks found. Stopping playback.',
      );
      await _player.stop();
      _onPlayErrorController.add((videoId, title));
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
        await _urlResolver.resolveSinglePendingItem(currentIndex, forceResolve: true);
        await play();
      }
    }
  }

  @override
  Future<void> play() async {
    _userWantsPlaying = true;
    _isStopping = false;
    _audioSessionController.cancelResumeOnInterruptionEnd();
    _lastPauseTimestamp = null;

    if (!_player.state.playing) {
      _statePublisher.updateState(
        (s) => s.copyWith(processingState: AudioProcessingState.buffering),
      );
    }

    await _readyCompleter.future
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});

    if (await _audioSessionController.requestFocus()) {
      await _player.play();
      if (_castHandler.castState?.connectionState ==
          CastConnectionState.connected) {
        await _castHandler.castService?.play();
      }
    } else {
      _userWantsPlaying = false;
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
    }
  }

  @override
  Future<void> pause() async {
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _pause();
  }

  Future<void> _pause() async {
    _userWantsPlaying = false;
    _lastPauseTimestamp = DateTime.now();
    await _player.pause();
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castHandler.castService?.pause();
    }
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _queueRepo.persistPosition(_player.state.position);
  }

  @override
  Future<void> stop() async {
    _userWantsPlaying = false;
    _lastPauseTimestamp = DateTime.now();
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      try {
        await _castHandler.castService?.disconnect();
      } catch (_) {}
    }
    _audioSessionController.cancelResumeOnInterruptionEnd();
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _queueRepo.persistPosition(_player.state.position);
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
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castHandler.castService?.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    await _readyCompleter.future
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    final currentIndex = _player.state.playlist.index;
    final currentTarget = _skipNavigator.resolveCurrentTarget(currentIndex, len);
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
    await _readyCompleter.future
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    // Standard behavior: if we've played more than 3 seconds of the current track,
    // "skip previous" just restarts the current track.
    if (_player.state.position.inSeconds >= 3) {
      await seek(Duration.zero);
      return;
    }

    final currentIndex = _player.state.playlist.index;
    final currentTarget = _skipNavigator.resolveCurrentTarget(currentIndex, len);
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

    await _readyCompleter.future
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});

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
        await _urlResolver.resolveSinglePendingItem(index, treatAsCurrent: true);

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
          _onPlayErrorController.add((
            track?.videoId ?? item?.id ?? '',
            item?.title ?? '',
          ));
          return;
        }
      }

      await _player.jump(index);
      // If the user wanted playback but the player is still paused after the
      // jump (e.g., tap an item while paused), resume — but only when not in
      // cast mode, since castSong (fired from _onPlaylistChanged) owns resumption.
      if (_userWantsPlaying &&
          !_player.state.playing &&
          _castHandler.castState?.connectionState !=
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
              final url = await _playVideoIdUseCase.resolveUrl(track.videoId);
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
    _lastPauseTimestamp = DateTime.now();
    await _prefs.setInt(
      'last_pause_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
    await _queueRepo.persistPosition(_player.state.position);
    _isStopping = true;
    await _player.stop();
    await _audioSessionController.releaseFocus();
    await super.onTaskRemoved();
  }

  void _onPlayerError(String error) async {
    // Always lift any pending transition mute on error so the player does not
    // remain permanently muted (e.g., when a URL resolve fails inside playNow).
    _volumeController.endTransitionMute();

    final currentItem = mediaItem.value;
    if (currentItem == null) return;
    final track = QueueTrack.fromMediaItem(currentItem);
    final videoId = track.videoId;

    // If this is a different track than the last retried one, reset the counter.
    // This ensures a new track always gets its one retry attempt, even when
    // _onPlaylistChanged's trackChanged reset was suppressed by _queueController.isResolvingItem.
    if (_lastRetriedVideoId != videoId) {
      _retryCount = 0;
    }

    if (_isRetrying ||
        _retryCount >= 1 ||
        _urlResolver.isPending(videoId)) {
      return;
    }

    _isRetrying = true;
    _lastRetriedVideoId = videoId;
    _retryCount++;
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(videoId);
      final updatedItem = track
          .copyWith(url: freshUrl)
          .toMediaItem(currentItem);
      final currentIndex = _player.state.playlist.index;

      final updatedMedia = _queueController.toMedia(updatedItem);

      final wasPlaying = _player.state.playing || _userWantsPlaying;
      final currentPos = _player.state.position;

      try {
        await _queueController.runBatch(
          () async {
            if (_castHandler.castState?.connectionState ==
                CastConnectionState.connected) {
              // Cast is active: send the refreshed URL to the cast device too.
              if (wasPlaying) {
                _castHandler.pausedForConnection = true;
                await _player.pause();
              }
              _volumeController.setLocalVolume(0.0);

              await _castHandler.castService?.castMedia(
                url: freshUrl,
                title: updatedItem.title,
                artist: updatedItem.artist,
                album: updatedItem.album,
                artworkUrl: updatedItem.artUri?.toString(),
              );

              // Update the local playlist with the refreshed URL.
              await _queueController.replaceAt(currentIndex, updatedMedia);
              await _player.jump(currentIndex);
              if (currentPos > Duration.zero) await _player.seek(currentPos);

              if (wasPlaying) {
                await _castHandler.waitForCastSessionState(
                  _castHandler.castService!,
                  SessionState.playing,
                );
                _castHandler.pausedForConnection = false;
                await play();
              } else {
                await _castHandler.castService?.pause();
              }
            } else {
              if (wasPlaying) await _player.pause();
              await _queueController.replaceAt(currentIndex, updatedMedia);
              await _player.jump(currentIndex);

              if (currentPos > Duration.zero) {
                await _player.seek(currentPos);
              }
              if (wasPlaying) await _player.play();
            }
          },
          isStopping: _isStopping,
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
      await _handlePlaybackConnectionFailure(videoId, currentItem.title);
    } finally {
      _isRetrying = false;
    }
  }

  Future<void> _ensureReady() async {
    if (_restoreStatus == RestoreStatus.restoring) return;

    if (_player.state.playing) {
      _setRestoreStatus(RestoreStatus.ready);
      return;
    }

    final playlist = _player.state.playlist;
    if (playlist.medias.isNotEmpty) {
      // Warm resume: the process (and therefore the in-memory playlist) is
      // still alive — this is the common Android case, since the player
      // keeps a foreground service/notification running in the background
      // (androidStopForegroundOnPause: false). The in-memory queue/index
      // is the ground truth here and must be preserved as-is; it must NOT
      // be replaced by `_doRestore()`, which reloads a snapshot from disk
      // that can be behind the live state (e.g. an autoplay Up Next append
      // or a reorder whose disk write raced with backgrounding). Doing so
      // is what used to cause "wrong current song after reopening" and
      // "play stays stuck" on Android after the app sat idle for a while.
      final idx = playlist.index;
      if (idx >= 0 && idx < playlist.medias.length) {
        final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
        final track = item != null ? QueueTrack.fromMediaItem(item) : null;
        final isDummy = track?.url?.contains('localhost/dummy') == true;
        if (track != null &&
            !isDummy &&
            !UrlStaleness.isStale(
              track.url,
              lastPauseTimestamp: _lastPauseTimestamp,
            )) {
          _setRestoreStatus(RestoreStatus.ready);
          return;
        }

        // The current item's stream URL simply expired while backgrounded
        // (YouTube URLs embed an `expire` timestamp valid for a few hours).
        // Refresh it in place instead of rebuilding the whole playlist.
        // Freeze the position hint first so the seek bar doesn't jump while
        // RestoreStatus.restoring is briefly emitted (PlayerNotifier reads
        // `savedPosition` on that transition).
        _savedPosition = _player.state.position;
        _setRestoreStatus(RestoreStatus.restoring);
        try {
          await _urlResolver.resolveSinglePendingItem(idx, forceResolve: true);
        } finally {
          _setRestoreStatus(RestoreStatus.ready);
          _statePublisher.invalidate();
          _statePublisher.updatePlaybackState();
        }
        // Best-effort prefetch of the next item too; failures here are
        // non-fatal since it is not the one about to play.
        unawaited(
          _urlResolver.resolveSinglePendingItem(idx + 1, forceResolve: true).catchError(
            (Object e) => dev.log(
              '[AudioHandler] Warm-resume prefetch of next item failed: $e',
            ),
          ),
        );
        return;
      }
    }

    // Cold start: the in-memory playlist is empty (fresh process), rebuild
    // it from the persisted queue.
    _setRestoreStatus(RestoreStatus.restoring);
    try {
      await _doRestore();
    } catch (e, stack) {
      dev.log('[AudioHandler] Error in _ensureReady/_doRestore: $e\n$stack');
    } finally {
      _setRestoreStatus(RestoreStatus.ready);
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
    }
  }

  Future<void> _doRestore() async {
    // One-shot migration: the User/UpNext queue split was introduced with
    // schemaVersion 18. On the first startup after the upgrade, clear any
    // pre-split persisted queue so the new section-aware playback starts
    // from a clean state. The flag is set after the clear so the next
    // restore proceeds normally.
    final splitDone = _prefs.getBool(kPostQueueSplitDoneKey) ?? false;
    if (!splitDone) {
      dev.log(
        '[AudioHandler] Queue User/UpNext split: clearing legacy queue on '
        'first run after upgrade.',
      );
      // Clears both the queue rows AND the playback pointer (QueueMeta) in
      // one atomic transaction, so the player doesn't try to resume a song
      // from a queue/position that no longer exists.
      await _queueRepo.clearQueue();
      await _prefs.setBool(kPostQueueSplitDoneKey, true);
      // Fall through to the empty-queue restore path below.
    }

    final restoreOnStartup = _prefs.getBool('restoreQueueOnStartup') ?? true;
    if (!restoreOnStartup) return;

    final rawEntries = await _queueRepo.restoreQueueWithSections();
    if (rawEntries.isEmpty) return;

    // Honor the current autoplay setting: if the user disabled Up Next
    // between sessions, strip the upnext section from the restored queue.
    final autoplayEnabled = _prefs.getBool(kAutoPlayUpNextKey) ?? true;
    final filtered =
        autoplayEnabled
            ? rawEntries
            : rawEntries
                .where((entry) => entry.section == QueueSection.user)
                .toList();

    final seenIds = <String>{};
    final items =
        filtered.map((entry) {
          final track = entry.track;
          final baseItem = track.toFreshMediaItem();
          final taggedItem =
              entry.section == QueueSection.upnext
                  ? QueueController.tagUpNext(baseItem)
                  : QueueController.tagUser(baseItem);
          final isLocalAndValid =
              track.isLocalFile && !UrlStaleness.isStale(track.url!);
          if (isLocalAndValid) {
            return _queueController.ensureQueueId(taggedItem, seenIds);
          }
          return _queueController.ensureQueueId(
            track
                .copyWith(clearUrl: true, needsUrl: true)
                .toMediaItem(taggedItem),
            seenIds,
          );
        }).toList();

    queue.add(items);

    // The playback pointer (index/videoId anchor/position/shuffle/repeat) is
    // read from the SAME atomic record that the queue itself was written
    // with (see QueueRepositoryImpl.persistQueue) — no more split-brain
    // between SharedPreferences and the Drift queue table.
    final meta = await _queueRepo.restoreMeta();

    int savedIndex = meta.currentIndex;
    final anchorVideoId = meta.currentVideoId;
    final positionalMatchesAnchor =
        anchorVideoId != null &&
        savedIndex >= 0 &&
        savedIndex < items.length &&
        items[savedIndex].id == anchorVideoId;

    if (savedIndex < 0 || savedIndex >= items.length) {
      savedIndex = 0;
    }
    if (anchorVideoId != null && !positionalMatchesAnchor) {
      // The raw index no longer lines up with the last-known track (e.g.
      // items were removed from the persisted queue by some other flow
      // between sessions). Fall back to locating the track by its stable
      // videoId instead of trusting the numeric index, which otherwise
      // tends to resume into index 0 — a track the user was very likely
      // not listening to.
      final byId = items.indexWhere((it) => it.id == anchorVideoId);
      if (byId != -1) {
        dev.log(
          '[AudioHandler] _doRestore: index/anchor mismatch '
          '(saved index=$savedIndex, resolved by videoId=$byId). '
          'Using id-based match to avoid resuming the wrong track.',
        );
        savedIndex = byId;
      }
    }

    var currentItem = items[savedIndex];
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(currentItem.id);
      final track = QueueTrack.fromMediaItem(
        currentItem,
      ).copyWith(url: freshUrl, needsUrl: false);
      currentItem = track.toMediaItem(currentItem);
      items[savedIndex] = currentItem;
    } catch (e) {
      dev.log(
        '[AudioHandler] _doRestore: failed URL resolve for index $savedIndex: $e',
      );
    }

    _savedPosition = meta.position;

    if (meta.shuffleMode != null) {
      final shuffleMode = meta.shuffleMode!;
      await _player.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
      _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
    }

    if (meta.repeatMode != null) {
      final repeatMode = meta.repeatMode!;
      final playlistMode = switch (repeatMode) {
        AudioServiceRepeatMode.none => PlaylistMode.none,
        AudioServiceRepeatMode.one => PlaylistMode.single,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => PlaylistMode.loop,
      };
      await _player.setPlaylistMode(playlistMode);
      _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
    }

    _isStopping = false;
    final restoredPlaylist = Playlist(
      items.map(_queueController.toMedia).toList(),
      index: savedIndex,
    );
    _userWantsPlaying = false;

    // Open with play: true to trigger stream decoding (needed for the player
    // to report duration on streaming URLs). We pause right after the seek.
    // Suppress intermediate playlist events: media_kit briefly reports an
    // empty playlist during open, which would otherwise sync/persist [].
    _queueController.beginResolving();
    try {
      await _player.open(restoredPlaylist, play: true);

      if (_savedPosition > Duration.zero) {
        try {
          await _player.stream.duration
              .where((d) => d > Duration.zero)
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
        await _player.seek(_savedPosition);
      }
      // Pause after restore — the user didn't ask for playback.
      if (_player.state.playing) {
        await _player.pause();
      }
    } finally {
      _queueController.endResolving();
      // Publish the final playlist to the queue stream before restore is
      // marked ready, so the full-player queue is populated immediately.
      _queueController.syncQueue(isStopping: _isStopping);
      // Seed mediaItem if playlist events were suppressed during open.
      final playlist = _player.state.playlist;
      final idx = playlist.index;
      if (idx >= 0 &&
          idx < playlist.medias.length &&
          mediaItem.valueOrNull == null) {
        final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
        if (item != null) {
          mediaItem.add(item);
        }
      }
      _statePublisher.updatePlaybackState();
    }
  }

  Future<void> persistQueue(List<MediaItem> items) async {
    await _queueRepo.persistQueue(
      items,
      currentIndex: _player.state.playlist.index,
      shuffleMode: playbackState.value.shuffleMode,
      repeatMode: playbackState.value.repeatMode,
    );
  }

  Future<void> restoreIfNeeded() => _ensureReady();

  void dispose() {
    _isStopping = true;
    _urlResolver.cancelLookahead();
    _playerErrorSub?.cancel();
    _connectivitySub?.cancel();
    _urlResolver.dispose();
    _audioSessionController.dispose();
    _onPlayErrorController.close();
    _restoreStatusController.close();
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
    return _browserHandler.getChildren(parentMediaId, options);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromMediaId
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) {
    return _browserHandler.playFromMediaId(mediaId, extras);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — search
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) {
    return _browserHandler.search(query, extras);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromSearch
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) {
    return _browserHandler.playFromSearch(query, extras);
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
