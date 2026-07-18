import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/url_staleness.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/connectivity_utils.dart';
import '../../../data/services/media_cache_service.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../domain/usecases/player/play_smart_mix_use_case.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';
import '../../../domain/usecases/home/get_discover_suggestions_use_case.dart';
import '../../../domain/usecases/home/get_new_releases_use_case.dart';
import '../../../domain/usecases/home/get_similar_artists_suggestions_use_case.dart';

import 'package:dart_cast/dart_cast.dart';
import '../../providers/cast_provider.dart';
import '../../../data/services/cast_service.dart';

import 'audio_cast_handler.dart';
import 'audio_android_auto_browser_handler.dart';
import 'audio_equalizer_handler.dart';

import '../../../domain/models/queue_section.dart';
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
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  late final PlayAlbumUseCase _playAlbumUseCase;
  late final PlayPlaylistUseCase _playPlaylistUseCase;
  late final PlaySmartMixUseCase _playSmartMixUseCase;
  late final GetNewReleasesUseCase _getNewReleasesUseCase;
  late final GetDiscoverSuggestionsUseCase _getDiscoverSuggestionsUseCase;
  late final GetSimilarArtistsSuggestionsUseCase
  _getSimilarArtistsSuggestionsUseCase;
  late final StartRadioUseCase _startRadioUseCase;

  late final AudioCastHandler _castHandler;
  late final AudioAndroidAutoBrowserHandler _browserHandler;
  late final AudioEqualizerHandler _equalizerHandler;

  /// Single [Connectivity] instance shared across the entire player module.
  /// Avoids multiple platform-channel registrations for the same signal.
  static final Connectivity _sharedConnectivity = Connectivity();

  Player get player => _player;

  Duration _crossfadeDuration = Duration.zero;
  Duration _lastPosition = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  int _retryCount = 0;
  bool _isRetrying = false;
  // Tracks the videoId of the last retried track so we can reset _retryCount
  // when a new track errors, even if _onPlaylistChanged's reset was suppressed
  // by _isResolvingItem being true during a concurrent URL resolution.
  String? _lastRetriedVideoId;
  bool _isStopping = false;
  bool _isCurrentSongLiked = false;
  bool _playOnInterruptionEnd = false;
  int _queueIdCounter = 0;
  String? _currentVideoId;
  String? _lastEmittedMediaItemId;
  Duration? _lastEmittedDuration;
  AudioProcessingState? _lastEmittedProcessingState;
  bool? _lastEmittedPlaying;
  StreamSubscription<String>? _playerErrorSub;
  final Set<String> _pendingResolutions = {};
  final List<int> _shuffledHistory = [];
  bool _isGoingBackward = false;
  Timer? _lookaheadTimer;
  int? _targetSkipIndex;
  bool _isTransitionMuted = false;
  bool _userWantsPlaying = false;
  bool _interruptedByNetworkDrop = false;
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

  // ── Resolving-item counter (replaces the old bool flag) ───────────────────
  // Using a counter instead of a boolean prevents premature flag clearing when
  // multiple _resolveSinglePendingItem calls run concurrently (e.g. resolving
  // items at indices 1 and 2 while index 0 is already playing).
  int _resolvingItemCount = 0;
  bool get _isResolvingItem => _resolvingItemCount > 0;
  final StreamController<(String videoId, String title)>
  _onPlayErrorController =
      StreamController<(String videoId, String title)>.broadcast();

  Stream<(String videoId, String title)> get onPlayError =>
      _onPlayErrorController.stream;

  static const String _actionShuffle = 'shuffle';
  static const String _actionRepeat = 'repeat';
  static const String _actionLike = 'like';
  static const String _actionStartRadio = 'start_radio';

  /// Key under [MediaItem.extras] that tags the queue section an item
  /// belongs to (`'user'` or `'upnext'`). See [QueueSection].
  static const String _kSectionKey = 'section';

  // Expose internals for delegate handlers
  double get lastSetVolume => _lastSetVolume;
  bool get userWantsPlaying => _userWantsPlaying;
  PlayVideoIdUseCase get playVideoIdUseCase => _playVideoIdUseCase;

  void setLocalVolume(double volume, {bool force = false}) =>
      _setLocalVolume(volume, force: force);

  SonoraAudioHandler({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required SharedPreferences prefs,
    required QueueRepository queueRepo,
  }) : _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase,
       _prefs = prefs,
       _queueRepo = queueRepo {
    _playAlbumUseCase = PlayAlbumUseCase(musicRepo);
    _playPlaylistUseCase = PlayPlaylistUseCase(musicRepo);
    _playSmartMixUseCase = PlaySmartMixUseCase(musicRepo);
    _getNewReleasesUseCase = GetNewReleasesUseCase(musicRepo, libraryRepo);
    _getDiscoverSuggestionsUseCase = GetDiscoverSuggestionsUseCase(
      musicRepo,
      libraryRepo,
    );
    _getSimilarArtistsSuggestionsUseCase = GetSimilarArtistsSuggestionsUseCase(
      musicRepo,
      libraryRepo,
    );
    _startRadioUseCase = StartRadioUseCase(musicRepo);

    _castHandler = AudioCastHandler(this);
    _browserHandler = AudioAndroidAutoBrowserHandler(
      audioHandler: this,
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
      playAlbumUseCase: _playAlbumUseCase,
      playPlaylistUseCase: _playPlaylistUseCase,
      playSmartMixUseCase: _playSmartMixUseCase,
      getNewReleasesUseCase: _getNewReleasesUseCase,
      getDiscoverSuggestionsUseCase: _getDiscoverSuggestionsUseCase,
      getSimilarArtistsSuggestionsUseCase: _getSimilarArtistsSuggestionsUseCase,
      connectivity: _sharedConnectivity,
    );

    _equalizerHandler = AudioEqualizerHandler(this);

    _setupAudioSession();
    _setupListeners();
    _playerErrorSub = _player.stream.error.listen(_onPlayerError);
    _connectivitySub = _sharedConnectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    unawaited(_initPlayerCache());
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

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _playOnInterruptionEnd = _player.state.playing;
              _pause();
              break;
            case AudioInterruptionType.duck:
              _setLocalVolume(_lastSetVolume * 20.0);
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_playOnInterruptionEnd) {
                play();
              }
              _playOnInterruptionEnd = false;
              break;
            case AudioInterruptionType.duck:
              _setLocalVolume(_lastSetVolume * 100.0);
              break;
          }
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (e) {
      dev.log('[AudioHandler] Failed to configure audio session: $e');
    }
  }

  Future<void> _initPlayerCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/sonora_stream_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final playerPlatform = _player.platform;
      if (playerPlatform is NativePlayer) {
        await playerPlatform.setProperty('cache', 'yes');
        await playerPlatform.setProperty('cache-on-disk', 'yes');
        await playerPlatform.setProperty('cache-dir', cacheDir.path);
        await playerPlatform.setProperty('demuxer-max-bytes', '20971520');
        await playerPlatform.setProperty('demuxer-max-back-bytes', '10485760');

        // Disable video decoding for audio-only playback.
        // Prevents mpv from allocating video resources that crash when
        // Android destroys the rendering surface in background.
        await playerPlatform.setProperty('video', 'no');

        // Fill audio gaps with silence instead of pausing/clicking on underruns.
        // Prevents crackling when Android throttles network in background.
        await playerPlatform.setProperty('audio-stream-silence', 'yes');

        dev.log(
          '[AudioHandler] Stream caching configured at: ${cacheDir.path}',
        );
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to configure player caching: $e');
    }
  }

  Future<bool> _requestAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      return await session.setActive(true);
    } catch (e) {
      dev.log('[AudioHandler] Failed to request audio focus: $e');
      return false;
    }
  }

  Future<void> _releaseAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      dev.log('[AudioHandler] Failed to release audio focus: $e');
    }
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
          !_isTransitionMuted &&
          !_castHandler.pausedForConnection) {
        _userWantsPlaying = false;
      }
      _updatePlaybackState();
    });
    _player.stream.buffering.listen((_) => _updatePlaybackState());
    _player.stream.completed.listen((_) => _updatePlaybackState());

    _player.stream.playlist.listen((playlist) {
      if (!_isResolvingItem) _updatePlaybackState();
      _onPlaylistChanged(playlist);
    });

    _player.stream.position.listen((pos) {
      _handleCrossfade(pos);
      _handlePositionTick(pos);
      if (_isTransitionMuted &&
          _player.state.playing &&
          pos.inMilliseconds > 150) {
        _endTransitionMute();
      }
    });
    _player.stream.buffer.listen(_onBufferedPositionChanged);

    _player.stream.shuffle.listen((shuffled) {
      final shuffleMode =
          shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      _updateState((s) => s.copyWith(shuffleMode: shuffleMode));
      _rebuildControls();
    });

    _player.stream.playlistMode.listen((mode) {
      final repeatMode = switch (mode) {
        PlaylistMode.none => AudioServiceRepeatMode.none,
        PlaylistMode.single => AudioServiceRepeatMode.one,
        PlaylistMode.loop => AudioServiceRepeatMode.all,
      };
      _updateState((s) => s.copyWith(repeatMode: repeatMode));
      _rebuildControls();
    });
  }

  AudioProcessingState _getProcessingState() {
    if (_player.state.buffering) {
      return AudioProcessingState.buffering;
    }
    if (_player.state.completed) {
      return AudioProcessingState.completed;
    }
    if (_player.state.playlist.medias.isEmpty) {
      return AudioProcessingState.idle;
    }
    return AudioProcessingState.ready;
  }

  void _updatePlaybackState() {
    if (_restoreStatus == RestoreStatus.restoring) return;

    final processing = _getProcessingState();
    final playing = _player.state.playing;

    if (processing == AudioProcessingState.ready) {
      _retryCount = 0;
    }

    final stateUnchanged =
        processing == _lastEmittedProcessingState &&
        playing == _lastEmittedPlaying;
    if (stateUnchanged) return;

    _lastEmittedProcessingState = processing;
    _lastEmittedPlaying = playing;

    final current = playbackState.value;
    final updatedState = current.copyWith(
      processingState: processing,
      playing: playing,
      updatePosition: _player.state.position,
      speed: _player.state.rate,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 1, 2],
    );

    playbackState.add(
      updatedState.copyWith(controls: _buildControls(updatedState)),
    );
  }

  void _updateState(
    PlaybackState Function(PlaybackState) update, {
    Duration? forcePosition,
  }) {
    final current = playbackState.value;
    final updated = update(current);
    final position =
        forcePosition ??
        (_restoreStatus == RestoreStatus.restoring
            ? _savedPosition
            : _player.state.position);
    playbackState.add(
      updated.copyWith(updatePosition: position, speed: _player.state.rate),
    );
  }

  List<MediaControl> _buildControls(PlaybackState current) {
    final shuffleIcon =
        current.shuffleMode == AudioServiceShuffleMode.all
            ? 'drawable/ic_shuffle'
            : 'drawable/ic_shuffle_off';

    final repeatIcon = switch (current.repeatMode) {
      AudioServiceRepeatMode.one => 'drawable/ic_repeat_one',
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => 'drawable/ic_repeat',
      _ => 'drawable/ic_repeat_off',
    };

    return [
      MediaControl.skipToPrevious,
      if (current.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: shuffleIcon,
        label:
            current.shuffleMode == AudioServiceShuffleMode.all
                ? 'Shuffle On'
                : 'Shuffle',
        name: _actionShuffle,
      ),
      MediaControl.custom(
        androidIcon: repeatIcon,
        label: switch (current.repeatMode) {
          AudioServiceRepeatMode.one => 'Repeat One',
          AudioServiceRepeatMode.all => 'Repeat All',
          _ => 'Repeat',
        },
        name: _actionRepeat,
      ),
      MediaControl.custom(
        androidIcon:
            _isCurrentSongLiked
                ? 'drawable/ic_favorite'
                : 'drawable/ic_favorite_border',
        label: _isCurrentSongLiked ? 'Unlike' : 'Like',
        name: _actionLike,
      ),
      MediaControl.custom(
        androidIcon: 'drawable/ic_radio',
        label: 'Start Radio',
        name: _actionStartRadio,
      ),
    ];
  }

  void _rebuildControls() {
    _updateState((s) => s.copyWith(controls: _buildControls(s)));
  }

  Future<void> _checkCurrentSongLiked(String videoId) async {
    _currentVideoId = videoId;
    try {
      final liked = await _libraryRepo.getLikedSong(videoId);
      if (_currentVideoId == videoId) {
        _isCurrentSongLiked = liked != null;
        _rebuildControls();
      }
    } catch (_) {}
  }

  void _onBufferedPositionChanged(Duration position) {
    final prev = playbackState.value.bufferedPosition;
    if ((position - prev).abs() >= const Duration(seconds: 2)) {
      _updateState((s) => s.copyWith(bufferedPosition: position));
    }
  }

  void _onPlaylistChanged(Playlist playlist) {
    if (_isStopping) return;

    final index = playlist.index;

    if (!_isResolvingItem) {
      _targetSkipIndex = null;
      _updateState((s) => s.copyWith(queueIndex: index));
      if (index >= 0) _prefs.setInt('last_playing_index', index);
    }

    if (!_isResolvingItem && index >= 0 && index < playlist.medias.length) {
      final media = playlist.medias[index];
      var item = media.extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        final playerDuration = _player.state.duration;
        if ((item.duration == null || item.duration == Duration.zero) &&
            playerDuration != Duration.zero) {
          item = item.copyWith(duration: playerDuration);
        }

        final trackChanged = item.id != _lastEmittedMediaItemId;
        final durationResolved =
            !trackChanged &&
            (_lastEmittedDuration == null ||
                _lastEmittedDuration == Duration.zero) &&
            (item.duration != null && item.duration != Duration.zero);
        if (trackChanged || durationResolved) {
          _lastEmittedMediaItemId = item.id;
          _lastEmittedDuration = item.duration;
          mediaItem.add(item);
          if (trackChanged) {
            _retryCount = 0;
            _checkCurrentSongLiked(item.id);
            if (_castHandler.castState?.connectionState ==
                CastConnectionState.connected) {
              if (item.extras?['needsUrl'] != true) {
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
      _resolvePendingItems(index).catchError(
        (Object e) => dev.log('[AudioHandler] _resolvePendingItems error: $e'),
      ),
    );

    if (!_isResolvingItem) {
      final items =
          playlist.medias
              .map((e) => e.extras?['mediaItem'] as MediaItem?)
              .nonNulls
              .toList();

      final newIds =
          items.map((e) => e.extras?['queueId'] as String? ?? e.id).toList();
      final currentIds =
          queue.value
              .map((e) => e.extras?['queueId'] as String? ?? e.id)
              .toList();
      final queueStructureChanged =
          newIds.length != currentIds.length ||
          !const ListEquality().equals(newIds, currentIds);
      if (queueStructureChanged) {
        queue.add(items);
        _queueRepo.persistQueue(items);
      }
    }

    if (!_isResolvingItem &&
        _crossfadeDuration > Duration.zero &&
        _player.state.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  Future<void> _resolvePendingItems(int currentIndex) async {
    await _resolveSinglePendingItem(currentIndex);
    await _resolveSinglePendingItem(currentIndex + 1);

    // Trigger pre-caching for the resolved upcoming track
    final playlist = _player.state.playlist;
    if (currentIndex + 1 < playlist.medias.length) {
      final media = playlist.medias[currentIndex + 1];
      final item = media.extras?['mediaItem'] as MediaItem?;
      final url = item?.extras?['url'] as String?;
      final needsUrl = item?.extras?['needsUrl'] == true;
      if (item != null &&
          url != null &&
          url.isNotEmpty &&
          !needsUrl &&
          !url.startsWith('file://') &&
          !url.startsWith('http://localhost')) {
        unawaited(MediaCacheService.instance.downloadToCache(item.id, url));
      }
    }

    // Clean up older cache files
    final activeIds =
        playlist.medias
            .skip(currentIndex)
            .take(5)
            .map((m) => (m.extras?['mediaItem'] as MediaItem?)?.id)
            .nonNulls
            .toList();
    unawaited(MediaCacheService.instance.cleanOldCacheFiles(activeIds));

    _lookaheadTimer?.cancel();
    _lookaheadTimer = Timer(const Duration(seconds: 20), () async {
      final actualIndex = _player.state.playlist.index;
      if (actualIndex == currentIndex && _player.state.playing) {
        await _resolveSinglePendingItem(currentIndex + 2);
        if (currentIndex + 2 < playlist.medias.length) {
          final media2 = playlist.medias[currentIndex + 2];
          final item2 = media2.extras?['mediaItem'] as MediaItem?;
          final url2 = item2?.extras?['url'] as String?;
          final needsUrl2 = item2?.extras?['needsUrl'] == true;
          if (item2 != null &&
              url2 != null &&
              url2.isNotEmpty &&
              !needsUrl2 &&
              !url2.startsWith('file://') &&
              !url2.startsWith('http://localhost')) {
            unawaited(
              MediaCacheService.instance.downloadToCache(item2.id, url2),
            );
          }
        }

        await Future.delayed(const Duration(seconds: 3));
        final finalIndex = _player.state.playlist.index;
        if (finalIndex == currentIndex && _player.state.playing) {
          await _resolveSinglePendingItem(currentIndex + 3);
          if (currentIndex + 3 < playlist.medias.length) {
            final media3 = playlist.medias[currentIndex + 3];
            final item3 = media3.extras?['mediaItem'] as MediaItem?;
            final url3 = item3?.extras?['url'] as String?;
            final needsUrl3 = item3?.extras?['needsUrl'] == true;
            if (item3 != null &&
                url3 != null &&
                url3.isNotEmpty &&
                !needsUrl3 &&
                !url3.startsWith('file://') &&
                !url3.startsWith('http://localhost')) {
              unawaited(
                MediaCacheService.instance.downloadToCache(item3.id, url3),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _resolveSinglePendingItem(
    int index, {
    bool forceResolve = false,
  }) async {
    if (index < 0) return;
    final playlist = _player.state.playlist;
    if (index >= playlist.medias.length) return;
    final media = playlist.medias[index];
    final item = media.extras?['mediaItem'] as MediaItem?;
    if (item == null) return;
    if (!forceResolve && item.extras?['needsUrl'] != true) return;

    final videoId = item.extras?['videoId'] as String?;
    if (videoId == null) return;

    if (!_pendingResolutions.add(videoId)) return;
    _resolvingItemCount++;
    try {
      // Background items timeout in 5 seconds, active item timeouts in 10 seconds.
      final isCurrent = index == playlist.index;
      final url = await _playVideoIdUseCase
          .resolveUrl(videoId)
          .timeout(Duration(seconds: isCurrent ? 10 : 5));

      final playlist2 = _player.state.playlist;
      if (index >= playlist2.medias.length) return;
      final currentMedia = playlist2.medias[index];
      final currentItem = currentMedia.extras?['mediaItem'] as MediaItem?;
      if (currentItem?.extras?['videoId'] != videoId) return;
      if (!forceResolve && currentItem?.extras?['needsUrl'] != true) return;

      final updatedItem = (currentItem ?? item).copyWith(
        extras: {...?item.extras, 'url': url, 'needsUrl': false},
      );
      final updatedMedia = Media(
        url,
        extras: {...?currentMedia.extras, 'mediaItem': updatedItem},
      );

      if (_castHandler.castState?.connectionState ==
          CastConnectionState.connected) {
        if (index == _player.state.playlist.index) {
          final wasPlaying = _player.state.playing || _userWantsPlaying;
          final currentPos = _player.state.position;
          if (wasPlaying) {
            _castHandler.pausedForConnection = true;
            await _player.pause();
          }
          _setLocalVolume(0.0);

          await _castHandler.castService?.castMedia(
            url: url,
            title: updatedItem.title,
            artist: updatedItem.artist,
            album: updatedItem.album,
            artworkUrl: updatedItem.artUri?.toString(),
          );

          // Update the local playlist with the resolved URL so local playback
          // can resume correctly if the cast session is disconnected later.
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
          await _player.jump(index);
          if (currentPos > Duration.zero) await _player.seek(currentPos);

          if (wasPlaying) {
            await _castHandler.waitForCastSessionState(
              _castHandler.castService!,
              SessionState.playing,
            );
            _castHandler.pausedForConnection = false;
            // Use play() (not _player.play()) so castService?.play() is also
            // sent to the cast device, keeping local player and cast in sync.
            await play();
          } else {
            await _castHandler.castService?.pause();
          }
        } else {
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
        }
      } else {
        if (index == _player.state.playlist.index) {
          final wasPlaying = _player.state.playing;
          final currentPos = _player.state.position;
          if (wasPlaying) await _player.pause();
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
          await _player.jump(index);
          if (currentPos > Duration.zero) await _player.seek(currentPos);
          if (wasPlaying) await _player.play();
        } else {
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
        }
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to resolve URL for item at $index: $e');
      final playlist3 = _player.state.playlist;
      if (index == playlist3.index) {
        await _handlePlaybackConnectionFailure(videoId, item.title);
      }
    } finally {
      _resolvingItemCount--;
      _pendingResolutions.remove(videoId);
      _syncQueue();
      if (!_isResolvingItem) {
        _lastEmittedProcessingState = null;
        _lastEmittedPlaying = null;
        _updatePlaybackState();
      }
      final actualIndex = _player.state.playlist.index;
      if (actualIndex >= 0) {
        _updateState((s) => s.copyWith(queueIndex: actualIndex));
        final playlist = _player.state.playlist;
        if (actualIndex < playlist.medias.length) {
          final media = playlist.medias[actualIndex];
          final item = media.extras?['mediaItem'] as MediaItem?;
          if (item != null) {
            _lastEmittedMediaItemId = item.id;
            _lastEmittedDuration = item.duration;
            mediaItem.add(item);
          }
        }
      }
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
      final url = mediaItem?.extras?['url'] as String?;
      final needsUrl = mediaItem?.extras?['needsUrl'] == true;
      final isLocal = url != null && url.startsWith('file://');

      bool isCached = false;
      if (mediaItem != null) {
        final cachedUri = await MediaCacheService.instance.getCachedFileUri(
          mediaItem.id,
        );
        isCached = cachedUri != null;
      }

      if (isLocal || isCached || !needsUrl) {
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
        await _resolveSinglePendingItem(currentIndex, forceResolve: true);
        await play();
      }
    }
  }

  @override
  Future<void> play() async {
    _userWantsPlaying = true;
    _isStopping = false;
    _playOnInterruptionEnd = false;
    await _readyCompleter.future.catchError((_) {});
    if (await _requestAudioFocus()) {
      await _player.play();
      if (_castHandler.castState?.connectionState ==
          CastConnectionState.connected) {
        await _castHandler.castService?.play();
      }
    }
  }

  @override
  Future<void> pause() async {
    _playOnInterruptionEnd = false;
    await _pause();
  }

  Future<void> _pause() async {
    _userWantsPlaying = false;
    await _player.pause();
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castHandler.castService?.pause();
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(
      'last_playing_position_ms',
      _player.state.position.inMilliseconds,
    );
    await _prefs.setInt('last_pause_timestamp', nowMs);
  }

  @override
  Future<void> stop() async {
    _userWantsPlaying = false;
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      try {
        await _castHandler.castService?.disconnect();
      } catch (_) {}
    }
    _playOnInterruptionEnd = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(
      'last_playing_position_ms',
      _player.state.position.inMilliseconds,
    );
    await _prefs.setInt('last_pause_timestamp', nowMs);
    _isStopping = true;
    _lookaheadTimer?.cancel();
    _endTransitionMute();
    await _player.stop();
    await _releaseAudioFocus();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _updateState((s) => s, forcePosition: position);
    if (_castHandler.castState?.connectionState ==
        CastConnectionState.connected) {
      await _castHandler.castService?.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    await _readyCompleter.future.catchError((_) {});

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    final currentIndex = _player.state.playlist.index;
    int currentTarget = _targetSkipIndex ?? currentIndex;
    if (currentTarget < 0 || currentTarget >= len) {
      currentTarget = currentIndex >= 0 ? currentIndex : 0;
    }

    int nextIndex;
    if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
      if (len > 1) {
        final random = Random();
        nextIndex = currentTarget;
        while (nextIndex == currentTarget) {
          nextIndex = random.nextInt(len);
        }
      } else {
        nextIndex = 0;
      }
    } else {
      nextIndex = currentTarget + 1;
      final repeatAll =
          playbackState.value.repeatMode == AudioServiceRepeatMode.all ||
          playbackState.value.repeatMode == AudioServiceRepeatMode.group;
      if (nextIndex >= len) {
        nextIndex = repeatAll ? 0 : len - 1;
      }
    }

    _targetSkipIndex = nextIndex;
    await skipToQueueItem(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    await _readyCompleter.future.catchError((_) {});

    final len = _player.state.playlist.medias.length;
    if (len == 0) return;

    final currentIndex = _player.state.playlist.index;
    int currentTarget = _targetSkipIndex ?? currentIndex;
    if (currentTarget < 0 || currentTarget >= len) {
      currentTarget = currentIndex >= 0 ? currentIndex : 0;
    }

    int prevIndex;
    if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
      if (_shuffledHistory.isNotEmpty) {
        prevIndex = _shuffledHistory.removeLast();
      } else {
        prevIndex = currentTarget;
      }
    } else {
      prevIndex = currentTarget - 1;
      final repeatAll =
          playbackState.value.repeatMode == AudioServiceRepeatMode.all ||
          playbackState.value.repeatMode == AudioServiceRepeatMode.group;
      if (prevIndex < 0) {
        prevIndex = repeatAll ? len - 1 : 0;
      }
    }

    _targetSkipIndex = prevIndex;
    _isGoingBackward = true;
    try {
      await skipToQueueItem(prevIndex);
    } finally {
      _isGoingBackward = false;
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _readyCompleter.future.catchError((_) {});

    final playlist = _player.state.playlist;
    if (index < 0 || index >= playlist.medias.length) return;

    _prepareTransitionMute();

    try {
      final currentIndex = playlist.index;
      if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all &&
          currentIndex >= 0 &&
          currentIndex != index &&
          !_isGoingBackward) {
        _shuffledHistory.add(currentIndex);
        if (_shuffledHistory.length > 50) {
          _shuffledHistory.removeAt(0);
        }
      }

      final media = playlist.medias[index];
      final item = media.extras?['mediaItem'] as MediaItem?;
      final needsUrl = item?.extras?['needsUrl'] == true;

      if (needsUrl) {
        await _resolveSinglePendingItem(index);
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
      _endTransitionMute();
      rethrow;
    }
  }

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyVolume(1.0);
  }

  void _prepareTransitionMute() {
    if (_player.state.playlist.medias.isNotEmpty) {
      _isTransitionMuted = true;
      _setLocalVolume(0.0, force: true);
    }
  }

  void _endTransitionMute() {
    if (!_isTransitionMuted) return;

    _setLocalVolume(_lastSetVolume * 100.0);
    _isTransitionMuted = false;
  }

  void _setLocalVolume(double volume, {bool force = false}) {
    if (!force &&
        _castHandler.castState?.connectionState ==
            CastConnectionState.connected) {
      _player.setVolume(0.0);
    } else {
      _player.setVolume(volume);
    }
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      if (!_isTransitionMuted) {
        _setLocalVolume(v * 100.0);
      }
    }
  }

  void _handleCrossfade(Duration position) {
    if (_crossfadeDuration == Duration.zero) return;
    final duration = _player.state.duration;
    if (duration == Duration.zero || !_player.state.playing) return;

    if (_isFadingIn) {
      final fadeMs = _crossfadeDuration.inMilliseconds;
      final vol = fadeMs > 0 ? position.inMilliseconds / fadeMs : 1.0;
      if (vol >= 1.0) {
        _applyVolume(1.0);
        _isFadingIn = false;
      } else {
        _applyVolume(vol);
      }
      return;
    }

    final remaining = duration - position;
    if (remaining > Duration.zero && remaining <= _crossfadeDuration) {
      _applyVolume(
        remaining.inMilliseconds / _crossfadeDuration.inMilliseconds,
      );
    } else if (remaining > _crossfadeDuration) {
      _applyVolume(1.0);
    }
  }

  void _handlePositionTick(Duration pos) {
    final jumpedBackward =
        pos < _lastPosition - const Duration(milliseconds: 500);
    final advancedEnough = pos >= _lastPosition + const Duration(seconds: 1);
    if (jumpedBackward || advancedEnough) {
      _updateState((s) => s);
    }
    _lastPosition = pos;
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffle(enabled);
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _shuffledHistory.clear();
    }
    _updateState((s) => s.copyWith(shuffleMode: shuffleMode));
    unawaited(_prefs.setString('last_shuffle_mode', shuffleMode.name));
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
    _updateState((s) => s.copyWith(repeatMode: repeatMode));
    unawaited(_prefs.setString('last_repeat_mode', repeatMode.name));
  }

  List<MediaItem> get _currentQueue =>
      _player.state.playlist.medias
          .map((e) => e.extras?['mediaItem'] as MediaItem?)
          .nonNulls
          .toList();

  /// Public read-only view of the current playlist, exposed for
  /// integrations (Android Auto, Cast) that need to inspect the queue
  /// without modifying it.
  List<MediaItem> get currentQueue => _currentQueue;

  /// User-queue portion of the current playlist (items not tagged as
  /// upnext). Single source of truth for the User/UpNext split used by
  /// the UI and Android Auto.
  List<MediaItem> get userQueue =>
      _currentQueue.where((it) => !isUpNext(it)).toList();

  /// Autoplay "Up Next" portion of the current playlist.
  List<MediaItem> get upNextQueue => _currentQueue.where(isUpNext).toList();

  // ── Queue section helpers (User Queue / Up Next) ───────────────────────────

  /// Returns the [QueueSection] of [item] based on [MediaItem.extras].
  /// Defaults to [QueueSection.user] for legacy items without the tag.
  static QueueSection sectionOf(MediaItem item) {
    return QueueSection.fromTag(item.extras?[_kSectionKey] as String?);
  }

  /// True if [item] belongs to the autoplay "Up Next" section.
  static bool isUpNext(MediaItem item) =>
      sectionOf(item) == QueueSection.upnext;

  /// Returns a copy of [item] tagged with the given [section].
  static MediaItem _tagSection(MediaItem item, QueueSection section) {
    if (sectionOf(item) == section) return item;
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    extras[_kSectionKey] = section.tag;
    return item.copyWith(extras: extras);
  }

  /// Tags [item] as a user-queue item (no-op if already tagged).
  static MediaItem _tagUser(MediaItem item) =>
      _tagSection(item, QueueSection.user);

  /// Tags [item] as an upnext item (no-op if already tagged).
  static MediaItem _tagUpNext(MediaItem item) =>
      _tagSection(item, QueueSection.upnext);

  MediaItem _ensureQueueId(MediaItem item, [Set<String>? seenIds]) {
    final existingId = item.extras?['queueId'] as String?;
    final isAlreadyInQueue =
        existingId != null &&
        _currentQueue.any((e) => e.extras?['queueId'] == existingId);
    final isDuplicateInBatch =
        existingId != null && seenIds != null && seenIds.contains(existingId);

    if (existingId != null && !isAlreadyInQueue && !isDuplicateInBatch) {
      seenIds?.add(existingId);
      return item;
    }
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    final newId =
        '${item.id}_${DateTime.now().microsecondsSinceEpoch}_${_queueIdCounter++}';
    extras['queueId'] = newId;
    seenIds?.add(newId);
    return item.copyWith(extras: extras);
  }

  Media _toMedia(MediaItem item) {
    // Default any untagged item to the user section. Real upnext tagging
    // happens upstream (see [appendUpNext]) so this is just a safety net
    // for legacy call-sites.
    final tagged = _tagUser(_ensureQueueId(item));

    final url = tagged.extras?['url'] as String?;
    final videoId = tagged.extras?['videoId'] as String? ?? tagged.id;
    if (url != null && url.isNotEmpty) {
      return Media(url, extras: {'mediaItem': tagged});
    }
    final dummy = 'http://localhost/dummy_$videoId.wav';
    return Media(dummy, extras: {'mediaItem': tagged});
  }

  Future<void> setQueue(
    List<MediaItem> items, {
    int initialIndex = 0,
    bool Function()? shouldAbort,
  }) async {
    _isStopping = false;
    _prepareTransitionMute();
    await _synchronizedOpen(() async {
      try {
        final seenIds = <String>{};
        final itemsWithKeys =
            items.map((item) => _ensureQueueId(item, seenIds)).toList();
        queue.add(itemsWithKeys);
        await _queueRepo.persistQueue(itemsWithKeys);
        final playlist = Playlist(
          itemsWithKeys.map(_toMedia).toList(),
          index: initialIndex,
        );
        _userWantsPlaying = false;
        await _player.open(playlist, play: false);
      } catch (e) {
        _endTransitionMute();
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
    _prepareTransitionMute();
    await _synchronizedOpen(() async {
      try {
        final seenIds = <String>{};
        var itemsWithKeys =
            items.map((item) => _ensureQueueId(item, seenIds)).toList();
        queue.add(itemsWithKeys);
        await _queueRepo.persistQueue(itemsWithKeys);

        if (initialIndex >= 0 && initialIndex < itemsWithKeys.length) {
          final initialItem = itemsWithKeys[initialIndex];
          if (initialItem.extras?['needsUrl'] == true) {
            final videoId =
                initialItem.extras?['videoId'] as String? ?? initialItem.id;
            try {
              final url = await _playVideoIdUseCase.resolveUrl(videoId);
              final resolved = initialItem.copyWith(
                extras: {...?initialItem.extras, 'url': url, 'needsUrl': false},
              );
              itemsWithKeys[initialIndex] = resolved;
              queue.add(itemsWithKeys);
              await _queueRepo.persistQueue(itemsWithKeys);
            } catch (e) {
              dev.log(
                '[AudioHandler] Failed to resolve initial item URL for $videoId: $e',
              );
            }
          }
        }

        final playlist = Playlist(
          itemsWithKeys.map(_toMedia).toList(),
          index: initialIndex,
        );
        final hasFocus = await _requestAudioFocus();
        _userWantsPlaying = hasFocus;
        await _player.open(playlist, play: hasFocus);
      } catch (e) {
        _endTransitionMute();
        rethrow;
      }
    }, shouldAbort: shouldAbort);
  }

  Future<void> playNext(MediaItem item) async {
    final ci = _player.state.playlist.index;
    final insertAt = (ci + 1).clamp(0, _player.state.playlist.medias.length);
    final media = _toMedia(item);
    _resolvingItemCount++;
    try {
      await _player.add(media);
      await _player.move(_player.state.playlist.medias.length - 1, insertAt);
    } finally {
      _resolvingItemCount--;
      _syncQueue();
      if (!_isResolvingItem) _updatePlaybackState();
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _player.add(_toMedia(mediaItem));
  }

  Future<void> addToQueue(MediaItem item) async {
    await addQueueItem(item);
  }

  Future<void> addAllToQueue(List<MediaItem> items) async {
    if (items.isEmpty) return;
    // Guard with _resolvingItemCount so _onPlaylistChanged suppresses
    // intermediate queue syncs and disk writes during the batch add.
    _resolvingItemCount++;
    try {
      for (final item in items) {
        await _player.add(_toMedia(item));
      }
    } finally {
      _resolvingItemCount--;
      _syncQueue();
      if (!_isResolvingItem) _updatePlaybackState();
    }
  }

  /// Appends [items] to the playlist tagging each as part of the autoplay
  /// "Up Next" section. Used by [PlayerNotifier] when refilling the queue
  /// with related tracks (gated by [Settings.autoPlayUpNext]).
  ///
  /// Safe to call with an empty list (no-op). The first item is appended
  /// last so [Media.extras] is preserved through the player.
  Future<void> appendUpNext(List<MediaItem> items) async {
    if (items.isEmpty) return;
    _resolvingItemCount++;
    try {
      for (final item in items) {
        await _player.add(_toMedia(_tagUpNext(item)));
      }
    } finally {
      _resolvingItemCount--;
      _syncQueue();
      if (!_isResolvingItem) _updatePlaybackState();
    }
  }

  /// Removes every item currently tagged as [QueueSection.upnext] from the
  /// underlying media_kit playlist, leaving the user queue untouched.
  ///
  /// The current playback is preserved (if the current item itself is
  /// upnext, it is left in place to avoid a jarring skip).
  Future<void> _purgeUpNext() async {
    final medias = _player.state.playlist.medias;
    final currentIndex = _player.state.playlist.index;

    // Walk back-to-front so indices stay valid as we remove.
    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].extras?['mediaItem'] as MediaItem?;
      if (item != null && isUpNext(item)) {
        await _player.remove(i);
      }
    }
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
    if (index < 0 || index >= _player.state.playlist.medias.length) return;
    await _player.remove(index);
  }

  Future<void> clearQueue() async {
    _userWantsPlaying = false;
    _lookaheadTimer?.cancel();
    await _player.stop();
    await _player.open(const Playlist([]), play: false);
    queue.add([]);
  }

  /// Removes every user-queue track (everything not tagged as
  /// [QueueSection.upnext]) from the underlying playlist, preserving the
  /// autoplay "Up Next" section.
  ///
  /// The currently playing track is always kept in place (mirroring
  /// [_purgeUpNext]) so a queue-clear action never interrupts playback.
  Future<void> purgeUserQueue() async {
    final medias = _player.state.playlist.medias;
    final currentIndex = _player.state.playlist.index;

    // Walk back-to-front so indices stay valid as we remove.
    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].extras?['mediaItem'] as MediaItem?;
      if (item != null && !isUpNext(item)) {
        await _player.remove(i);
      }
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final len = _player.state.playlist.medias.length;

    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;
    if (oldIndex == newIndex) return;

    // A queue reorder shifts indices; invalidate the pending skip target so
    // the next skipToNext/Prev computes the correct index from scratch.
    _targetSkipIndex = null;

    // Capture the up-next boundary BEFORE the move: the moved item's final
    // section is decided against the pre-move layout (an upnext item
    // dragged above the boundary is promoted to user; a user item dragged
    // to/past the boundary is demoted to upnext).
    int? boundary;
    for (int i = 0; i < len; i++) {
      final it =
          _player.state.playlist.medias[i].extras?['mediaItem'] as MediaItem?;
      if (it != null && isUpNext(it)) {
        boundary = i;
        break;
      }
    }

    // Guard with _resolvingItemCount so _onPlaylistChanged suppresses
    // intermediate queue syncs during the move + possible retag.
    _resolvingItemCount++;
    try {
      final toIndex = oldIndex < newIndex ? newIndex + 1 : newIndex;
      await _player.move(oldIndex, toIndex);
      await _retagMovedItem(newIndex, boundary);
    } finally {
      _resolvingItemCount--;
      _syncQueue();
      if (!_isResolvingItem) _updatePlaybackState();
    }
  }

  /// Re-tags the item now sitting at [newIndex] based on the up-next
  /// [boundary] captured before the move. Replaces the underlying media
  /// in-place (remove + add + move) since media_kit has no update API.
  ///
  /// The currently playing item is never re-tagged: removing it would
  /// interrupt playback.
  Future<void> _retagMovedItem(int newIndex, int? boundary) async {
    final playlist = _player.state.playlist;
    if (newIndex < 0 || newIndex >= playlist.medias.length) return;
    if (newIndex == playlist.index) return;

    final media = playlist.medias[newIndex];
    final item = media.extras?['mediaItem'] as MediaItem?;
    if (item == null) return;

    final target =
        (boundary == null || newIndex < boundary)
            ? QueueSection.user
            : QueueSection.upnext;
    if (sectionOf(item) == target) return;

    final retagged = _tagSection(item, target);
    final newMedia = Media(
      media.uri,
      extras: {...?media.extras, 'mediaItem': retagged},
    );
    await _player.remove(newIndex);
    await _player.add(newMedia);
    await _player.move(_player.state.playlist.medias.length - 1, newIndex);
  }

  @override
  Future<void> onTaskRemoved() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(
      'last_playing_position_ms',
      _player.state.position.inMilliseconds,
    );
    await _prefs.setInt('last_pause_timestamp', nowMs);
    _isStopping = true;
    await _player.stop();
    await _releaseAudioFocus();
    await super.onTaskRemoved();
  }

  void _onPlayerError(String error) async {
    // Always lift any pending transition mute on error so the player does not
    // remain permanently muted (e.g., when a URL resolve fails inside playNow).
    _endTransitionMute();

    final currentItem = mediaItem.value;
    final videoId = currentItem?.extras?['videoId'] as String?;
    if (videoId == null) return;

    // If this is a different track than the last retried one, reset the counter.
    // This ensures a new track always gets its one retry attempt, even when
    // _onPlaylistChanged's trackChanged reset was suppressed by _isResolvingItem.
    if (_lastRetriedVideoId != videoId) {
      _retryCount = 0;
    }

    if (_isRetrying ||
        _retryCount >= 1 ||
        _pendingResolutions.contains(videoId)) {
      return;
    }

    _isRetrying = true;
    _lastRetriedVideoId = videoId;
    _retryCount++;
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(videoId);
      final updatedItem = currentItem!.copyWith(
        extras: {...?currentItem.extras, 'url': freshUrl},
      );
      final currentIndex = _player.state.playlist.index;

      final updatedMedia = Media(freshUrl, extras: {'mediaItem': updatedItem});

      final wasPlaying = _player.state.playing || _userWantsPlaying;
      final currentPos = _player.state.position;

      _resolvingItemCount++;
      try {
        if (_castHandler.castState?.connectionState ==
            CastConnectionState.connected) {
          // Cast is active: send the refreshed URL to the cast device too.
          if (wasPlaying) {
            _castHandler.pausedForConnection = true;
            await _player.pause();
          }
          _setLocalVolume(0.0);

          await _castHandler.castService?.castMedia(
            url: freshUrl,
            title: updatedItem.title,
            artist: updatedItem.artist,
            album: updatedItem.album,
            artworkUrl: updatedItem.artUri?.toString(),
          );

          // Update the local playlist with the refreshed URL.
          await _player.remove(currentIndex);
          await _player.add(updatedMedia);
          await _player.move(
            _player.state.playlist.medias.length - 1,
            currentIndex,
          );
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
          await _player.remove(currentIndex);
          await _player.add(updatedMedia);
          await _player.move(
            _player.state.playlist.medias.length - 1,
            currentIndex,
          );
          await _player.jump(currentIndex);

          if (currentPos > Duration.zero) {
            await _player.seek(currentPos);
          }
          if (wasPlaying) await _player.play();
        }
      } finally {
        _resolvingItemCount--;
        _syncQueue();
        if (!_isResolvingItem) {
          _lastEmittedProcessingState = null;
          _lastEmittedPlaying = null;
          _updatePlaybackState();
        }
        final actualIndex = _player.state.playlist.index;
        if (actualIndex >= 0) {
          _updateState((s) => s.copyWith(queueIndex: actualIndex));
        }
      }
    } catch (e) {
      await _handlePlaybackConnectionFailure(
        videoId,
        currentItem?.title ?? videoId,
      );
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
      final idx = playlist.index;
      if (idx >= 0 && idx < playlist.medias.length) {
        final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
        final url = item?.extras?['url'] as String?;
        final isDummy = url?.contains('localhost/dummy') == true;
        if (!isDummy && !UrlStaleness.isStale(url)) {
          _setRestoreStatus(RestoreStatus.ready);
          return;
        }
      }
    }

    _setRestoreStatus(RestoreStatus.restoring);
    try {
      await _doRestore();
    } catch (e, stack) {
      dev.log('[AudioHandler] Error in _ensureReady/_doRestore: $e\n$stack');
    } finally {
      _setRestoreStatus(RestoreStatus.ready);
      _lastEmittedProcessingState = null;
      _lastEmittedPlaying = null;
      _updatePlaybackState();
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
      await _queueRepo.clearQueue();
      await _prefs.setBool(kPostQueueSplitDoneKey, true);
      // Reset last-known playback position so the player doesn't try to
      // resume a song from a queue that no longer exists.
      await _prefs.remove('last_playing_index');
      await _prefs.remove('last_playing_position_ms');
      // Fall through to the empty-queue restore path below.
    }

    final restoreOnStartup = _prefs.getBool('restoreQueueOnStartup') ?? true;
    if (!restoreOnStartup) return;

    final rawItems = await _queueRepo.restoreQueue();
    if (rawItems.isEmpty) return;

    // Honor the current autoplay setting: if the user disabled Up Next
    // between sessions, strip the upnext section from the restored queue.
    final autoplayEnabled = _prefs.getBool(kAutoPlayUpNextKey) ?? true;
    final filtered =
        autoplayEnabled
            ? rawItems
            : rawItems
                .where((it) => sectionOf(it) == QueueSection.user)
                .toList();

    final seenIds = <String>{};
    final items =
        filtered.map((item) {
          final url = item.extras?['url'] as String?;
          final isLocalAndValid =
              url != null &&
              url.startsWith('file://') &&
              !UrlStaleness.isStale(url);
          if (isLocalAndValid) return _ensureQueueId(item, seenIds);
          return _ensureQueueId(
            item.copyWith(
              extras: {...?item.extras, 'needsUrl': true, 'url': null},
            ),
            seenIds,
          );
        }).toList();

    queue.add(items);

    int savedIndex = _prefs.getInt('last_playing_index') ?? 0;
    if (savedIndex < 0 || savedIndex >= items.length) savedIndex = 0;

    var currentItem = items[savedIndex];
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(currentItem.id);
      currentItem = currentItem.copyWith(
        extras: {...?currentItem.extras, 'url': freshUrl, 'needsUrl': false},
      );
      items[savedIndex] = currentItem;
    } catch (e) {
      dev.log(
        '[AudioHandler] _doRestore: failed URL resolve for index $savedIndex: $e',
      );
    }

    final savedPosMs = _prefs.getInt('last_playing_position_ms') ?? 0;
    _savedPosition = Duration(milliseconds: savedPosMs);

    final savedShuffleName = _prefs.getString('last_shuffle_mode');
    if (savedShuffleName != null) {
      final shuffleMode = AudioServiceShuffleMode.values.firstWhere(
        (m) => m.name == savedShuffleName,
        orElse: () => AudioServiceShuffleMode.none,
      );
      await _player.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
      _updateState((s) => s.copyWith(shuffleMode: shuffleMode));
    }

    final savedRepeatName = _prefs.getString('last_repeat_mode');
    if (savedRepeatName != null) {
      final repeatMode = AudioServiceRepeatMode.values.firstWhere(
        (m) => m.name == savedRepeatName,
        orElse: () => AudioServiceRepeatMode.none,
      );
      final playlistMode = switch (repeatMode) {
        AudioServiceRepeatMode.none => PlaylistMode.none,
        AudioServiceRepeatMode.one => PlaylistMode.single,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => PlaylistMode.loop,
      };
      await _player.setPlaylistMode(playlistMode);
      _updateState((s) => s.copyWith(repeatMode: repeatMode));
    }

    _isStopping = false;
    final restoredPlaylist = Playlist(
      items.map(_toMedia).toList(),
      index: savedIndex,
    );
    _userWantsPlaying = false;
    await _player.open(restoredPlaylist, play: false);

    if (savedPosMs > 0) {
      try {
        await _player.stream.duration
            .where((d) => d > Duration.zero)
            .first
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      await _player.seek(_savedPosition);
    }
  }

  Future<void> persistQueue(List<MediaItem> items) async {
    await _queueRepo.persistQueue(items);
  }

  Future<void> restoreIfNeeded() => _ensureReady();

  void _syncQueue() {
    final playlist = _player.state.playlist;
    final items =
        playlist.medias
            .map((e) => e.extras?['mediaItem'] as MediaItem?)
            .nonNulls
            .toList();

    final newIds =
        items.map((e) => e.extras?['queueId'] as String? ?? e.id).toList();
    final currentIds =
        queue.value
            .map((e) => e.extras?['queueId'] as String? ?? e.id)
            .toList();
    final queueStructureChanged =
        newIds.length != currentIds.length ||
        !const ListEquality().equals(newIds, currentIds);

    if (queueStructureChanged) {
      queue.add(items);
      if (!_isStopping) {
        _queueRepo.persistQueue(items);
      }
    }
  }

  void dispose() {
    _isStopping = true;
    _lookaheadTimer?.cancel();
    _playerErrorSub?.cancel();
    _connectivitySub?.cancel();
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
    _isCurrentSongLiked = !_isCurrentSongLiked;
    _rebuildControls();
    try {
      final current =
          _currentQueue
              .where((item) => item.id == mediaItem.value?.id)
              .firstOrNull;
      final videoId = current?.id ?? (mediaItem.value?.id ?? '');
      await _libraryRepo.toggleLikedSong(
        LikedSongModel(
          videoId: videoId,
          title: current?.title ?? 'Unknown',
          artist: current?.artist ?? 'Unknown Artist',
          thumbnailUrl: current?.artUri?.toString(),
          addedAt: DateTime.now(),
          duration: current?.duration?.inSeconds,
          isVideo: current?.extras?['isVideo'] == true,
          isExplicit: current?.extras?['isExplicit'] == true,
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
      case _actionShuffle:
        final current = playbackState.value.shuffleMode;
        final next =
            current == AudioServiceShuffleMode.none
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none;
        await setShuffleMode(next);
        break;

      case _actionRepeat:
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

      case _actionLike:
        final item = mediaItem.value;
        if (item == null) return null;
        _isCurrentSongLiked = !_isCurrentSongLiked;
        _rebuildControls();
        await _libraryRepo.toggleLikedSong(
          LikedSongModel(
            videoId: item.id,
            title: item.title,
            artist: item.artist ?? 'Unknown Artist',
            thumbnailUrl: item.artUri?.toString(),
            addedAt: DateTime.now(),
            duration: item.duration?.inSeconds,
            isVideo: item.extras?['isVideo'] == true,
            isExplicit: item.extras?['isExplicit'] == true,
          ),
        );
        break;

      case _actionStartRadio:
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
