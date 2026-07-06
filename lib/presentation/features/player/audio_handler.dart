import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/url_staleness.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

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

  Player get player => _player;

  Duration _crossfadeDuration = Duration.zero;
  Duration _lastPosition = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  int _retryCount = 0;
  bool _isRetrying = false;
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
    );

    _setupAudioSession();
    _setupListeners();
    _playerErrorSub = _player.stream.error.listen(_onPlayerError);
    unawaited(_initPlayerCache());
    unawaited(_ensureReady());
  }

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    await _castHandler.updateCastState(state, service);
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
        await playerPlatform.setProperty('demuxer-max-bytes', '104857600');
        await playerPlatform.setProperty('demuxer-max-back-bytes', '52428800');
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

    _resolvePendingItems(index);

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

    _lookaheadTimer?.cancel();
    _lookaheadTimer = Timer(const Duration(seconds: 20), () async {
      final actualIndex = _player.state.playlist.index;
      if (actualIndex == currentIndex && _player.state.playing) {
        await _resolveSinglePendingItem(currentIndex + 2);
        await Future.delayed(const Duration(seconds: 3));
        final finalIndex = _player.state.playlist.index;
        if (finalIndex == currentIndex && _player.state.playing) {
          await _resolveSinglePendingItem(currentIndex + 3);
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
      final url = await _playVideoIdUseCase.resolveUrl(videoId);

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
    final updatedItem = _ensureQueueId(item);

    final url = updatedItem.extras?['url'] as String?;
    final videoId = updatedItem.extras?['videoId'] as String? ?? updatedItem.id;
    if (url != null && url.isNotEmpty) {
      return Media(url, extras: {'mediaItem': updatedItem});
    }
    final dummy = 'http://localhost/dummy_$videoId.wav';
    return Media(dummy, extras: {'mediaItem': updatedItem});
  }

  Future<void> setQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    _isStopping = false;
    _prepareTransitionMute();
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
  }

  Future<void> playNow(List<MediaItem> items, {int initialIndex = 0}) async {
    _isStopping = false;
    _prepareTransitionMute();
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
    for (final item in items) {
      await _player.add(_toMedia(item));
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

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final len = _player.state.playlist.medias.length;

    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;

    final toIndex = oldIndex < newIndex ? newIndex + 1 : newIndex;
    await _player.move(oldIndex, toIndex);
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
    if (_isRetrying || _retryCount >= 1) {
      return;
    }
    final currentItem = mediaItem.value;
    final videoId = currentItem?.extras?['videoId'] as String?;
    if (videoId == null) {
      return;
    }

    _isRetrying = true;
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
      _onPlayErrorController.add((videoId, currentItem?.title ?? videoId));
      if (_player.state.playlist.medias.length >
          _player.state.playlist.index + 1) {
        await _player.next();
      } else {
        await _player.stop();
      }
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
    final restoreOnStartup = _prefs.getBool('restoreQueueOnStartup') ?? true;
    if (!restoreOnStartup) return;

    final rawItems = await _queueRepo.restoreQueue();
    if (rawItems.isEmpty) return;

    final seenIds = <String>{};
    final items =
        rawItems.map((item) {
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
