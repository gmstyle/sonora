import 'dart:async';
import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/url_staleness.dart';
import '../../../domain/repositories/queue_repository.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:audio_session/audio_session.dart';
import 'package:collection/collection.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:media_kit/media_kit.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';

import 'package:dart_cast/dart_cast.dart';
import '../../providers/cast_provider.dart';
import '../../../data/services/cast_service.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final Player _player = Player(
    configuration: const PlayerConfiguration(pitch: true),
  );
  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  late final PlayAlbumUseCase _playAlbumUseCase;
  late final PlayPlaylistUseCase _playPlaylistUseCase;

  CastState? _castState;
  SonoraCastService? _castService;
  bool _pausedForConnection = false;

  Player get player => _player;

  Duration _crossfadeDuration = Duration.zero;
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
  final StreamController<(String videoId, String title)>
  _onPlayErrorController =
      StreamController<(String videoId, String title)>.broadcast();

  Stream<(String videoId, String title)> get onPlayError =>
      _onPlayErrorController.stream;

  // ── Android Auto extras ──────────────────────────────────────────────────────
  static const String _kContentStyleBrowsable =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const String _kContentStylePlayable =
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const int _kStyleList = 1;

  static const String _actionShuffle = 'shuffle';
  static const String _actionRepeat = 'repeat';
  static const String _actionLike = 'like';
  static const String _actionSleepTimer = 'sleep_timer';

  // ── AA browse-tree action IDs ──────────────────────────────────────────────
  static const String _actionPlayAlbum = '__action__:play_album:';
  static const String _actionShuffleAlbum = '__action__:shuffle_album:';
  static const String _actionLikeAlbum = '__action__:like_album:';
  static const String _actionPlayArtist = '__action__:play_artist:';
  static const String _actionShuffleArtist = '__action__:shuffle_artist:';
  static const String _actionFollowArtist = '__action__:follow_artist:';
  static const String _actionPlayPlaylist = '__action__:play_playlist:';
  static const String _actionShufflePlaylist = '__action__:shuffle_playlist:';
  static const String _actionLikePlaylist = '__action__:like_playlist:';

  // ── AA content tree IDs ──────────────────────────────────────────────────────
  static const String _rootId = '/';
  static const String _homeId = '__home__';
  static const String _libraryId = '__library__';
  static const String _recentId = '__recent__';
  static const String _likedId = '__liked__';
  static const String _playlistsId = '__playlists__';
  static const String _artistsId = '__artists__';
  static const String _albumsId = '__albums__';
  static const String _historyId = '__history__';
  static const String _homeSectionPrefix = '__home_section__:';
  static const String _playlistPrefix = '__playlist__:';
  static const String _artistPrefix = '__artist__:';
  static const String _homeAlbumPrefix = '__home_album__:';
  static const String _homePlaylistPrefix = '__home_playlist__:';

  SonoraAudioHandler({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required SharedPreferences prefs,
    required QueueRepository queueRepo,
  }) : _musicRepo = musicRepo,
       _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase,
       _prefs = prefs,
       _queueRepo = queueRepo {
    _playAlbumUseCase = PlayAlbumUseCase(musicRepo);
    _playPlaylistUseCase = PlayPlaylistUseCase(musicRepo);
    _setupAudioSession();
    _setupListeners();
    _playerErrorSub = _player.stream.error.listen(_onPlayerError);
    _initRestore();
  }

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    _castService = service;

    if (state.connectionState == CastConnectionState.connecting) {
      if (_player.state.playing) {
        _pausedForConnection = true;
        await _player.pause();
      }
    } else if (state.connectionState == CastConnectionState.connected) {
      if (_castState?.connectionState != CastConnectionState.connected) {
        _setLocalVolume(0.0);
        await _castCurrentSong(state, service);
        _pausedForConnection = false;
      }
    } else if (state.connectionState == CastConnectionState.disconnected ||
        state.connectionState == CastConnectionState.error) {
      if (_castState?.connectionState == CastConnectionState.connected) {
        _setLocalVolume(_lastSetVolume * 100.0, force: true);
      }
      if (_pausedForConnection) {
        await _player.play();
        _pausedForConnection = false;
      }
    }

    _castState = state;
  }

  Future<void> _castCurrentSong(
    CastState state,
    SonoraCastService service,
  ) async {
    final item = mediaItem.value;
    if (item == null) return;
    final currentPos = _player.state.position;
    await _castSong(item, state, service, startPosition: currentPos);
  }

  Future<void> _castSong(
    MediaItem item,
    CastState state,
    SonoraCastService service, {
    Duration? startPosition,
  }) async {
    final wasPlaying = _player.state.playing || _pausedForConnection;
    if (wasPlaying) await _player.pause();
    _setLocalVolume(0.0);

    String? url = item.extras?['url'] as String?;
    if (url == null || url.isEmpty || item.extras?['needsUrl'] == true) {
      try {
        url = await _playVideoIdUseCase.resolveUrl(item.id);
      } catch (_) {
        return;
      }
    }

    await service.castMedia(
      url: url,
      title: item.title,
      artist: item.artist,
      album: item.album,
      artworkUrl: item.artUri?.toString(),
      startPosition: startPosition,
    );

    if (wasPlaying) {
      await _waitForCastSessionState(service, SessionState.playing);
      await _player.play();
    } else {
      await service.pause();
    }
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
              _pause(releaseFocus: false);
              break;
            case AudioInterruptionType.duck:
              _setLocalVolume(20.0);
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
              _setLocalVolume(100.0);
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

  Stream<Duration?> get durationStream =>
      _player.stream.duration.map((d) => d == Duration.zero ? null : d);

  /// Exposes the raw position stream from media_kit so that UI layers can
  /// subscribe to it directly without going through [playbackState], which
  /// would cause Android Auto to re-render the queue view on every tick.
  Stream<Duration> get positionStream => _player.stream.position;

  void _setupListeners() {
    _player.stream.playing.listen((_) => _updatePlaybackState());
    _player.stream.buffering.listen((_) => _updatePlaybackState());
    _player.stream.completed.listen((_) => _updatePlaybackState());
    _player.stream.playlist.listen((_) => _updatePlaybackState());

    // Crossfade only — do NOT emit playbackState here.
    // Android Auto interpolates position from the updatePosition+updateTime
    // already set in _updatePlaybackState. Emitting playbackState on every
    // position tick (~5 Hz) causes AA to continuously re-render the queue
    // view, producing visible flashes and preventing scrolling.
    _player.stream.position.listen(_handleCrossfade);
    _player.stream.buffer.listen(_onBufferedPositionChanged);
    _player.stream.playlist.listen(_onPlaylistChanged);

    _player.stream.shuffle.listen((shuffled) {
      final shuffleMode =
          shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
      _rebuildControls();
    });

    _player.stream.playlistMode.listen((mode) {
      final repeatMode = switch (mode) {
        PlaylistMode.none => AudioServiceRepeatMode.none,
        PlaylistMode.single => AudioServiceRepeatMode.one,
        PlaylistMode.loop => AudioServiceRepeatMode.all,
      };
      playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
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
    final processing = _getProcessingState();
    final playing = _player.state.playing;

    if (processing == AudioProcessingState.ready) {
      _retryCount = 0;
    }

    // Skip redundant playbackState emissions to avoid Android Auto
    // continuously re-rendering the queue view. media_kit fires
    // player state streams frequently. We only need to notify AA when the
    // logical state visible to the user has actually changed.
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

  List<MediaControl> _buildControls(PlaybackState current) {
    return [
      MediaControl.skipToPrevious,
      if (current.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: 'drawable/ic_shuffle',
        label:
            current.shuffleMode == AudioServiceShuffleMode.all
                ? 'Shuffle On'
                : 'Shuffle',
        name: _actionShuffle,
      ),
      MediaControl.custom(
        androidIcon: 'drawable/ic_repeat',
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
        androidIcon: 'drawable/ic_timer',
        label: 'Sleep Timer',
        name: _actionSleepTimer,
      ),
    ];
  }

  void _rebuildControls() {
    final current = playbackState.value;
    playbackState.add(current.copyWith(controls: _buildControls(current)));
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
    // Throttle: update AA only when the buffered position has advanced by at
    // least 2 seconds to avoid continuous PlaybackState emissions that cause
    // the Android Auto queue view to flash and reset its scroll position.
    final prev = playbackState.value.bufferedPosition;
    if ((position - prev).abs() >= const Duration(seconds: 2)) {
      playbackState.add(
        playbackState.value.copyWith(bufferedPosition: position),
      );
    }
  }

  void _onPlaylistChanged(Playlist playlist) {
    if (_isStopping) return;

    final index = playlist.index;

    // Do NOT emit queueIndex or persist index during internal atomic operations
    // (remove/add/move sequences in _resolveSinglePendingItem). Those operations
    // cause playlist events with transient intermediate indices that would
    // corrupt state.currentIndex in PlayerNotifier, causing skip to go to the
    // wrong item. The correct queueIndex is emitted explicitly after the
    // sequence completes.
    if (!_isResolvingItem) {
      playbackState.add(playbackState.value.copyWith(queueIndex: index));
      if (index >= 0) _prefs.setInt('last_playing_index', index);
    }

    _resolvePendingItems(index);

    if (!_isResolvingItem && index >= 0 && index < playlist.medias.length) {
      final media = playlist.medias[index];
      var item = media.extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        final playerDuration = _player.state.duration;
        // Se il MediaItem dinamico o late-binded non ha durata impostata,
        // recuperiamo la durata effettiva dal player per non bloccare la progress bar.
        if ((item.duration == null || item.duration == Duration.zero) &&
            playerDuration != Duration.zero) {
          item = item.copyWith(duration: playerDuration);
        }

        // Emit mediaItem only when something meaningful changes:
        // - the track ID changed (new song), or
        // - the duration was previously unknown and is now available.
        // media_kit fires streams for many internal reasons (buffer updates,
        // URL resolution, shuffle state) even when the current track hasn't changed.
        // Every mediaItem.add triggers an Android Auto UI refresh that resets
        // the queue scroll position.
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
            _checkCurrentSongLiked(item.id);
            if (_castState?.connectionState == CastConnectionState.connected) {
              if (item.extras?['needsUrl'] != true) {
                _castSong(item, _castState!, _castService!);
              }
            }
          }
        }
      }
    }

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
      // Emit queue only when the list of IDs changes (i.e. songs are added/removed/reordered).
      // Skipping re-emission when only internal metadata (e.g. resolved URL) changed prevents
      // Android Auto from resetting the queue scroll position on every URL resolution.
      final queueStructureChanged =
          newIds.length != currentIds.length ||
          !const ListEquality().equals(newIds, currentIds);
      if (queueStructureChanged) {
        queue.add(items);
        _queueRepo.persistQueue(items);
      }
    }

    // Crossfade fade-in is only triggered on actual track transitions,
    // not during internal URL resolve operations (which suppress _isResolvingItem).
    if (!_isResolvingItem &&
        _crossfadeDuration > Duration.zero &&
        _player.state.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  /// Pre-resolves stream URLs for pending items ([needsUrl]) before they
  /// become current: resolves the item at [currentIndex] if needed (user
  /// skipped to a pending track), and proactively resolves the next 2 items
  /// so playback can transition seamlessly.
  Future<void> _resolvePendingItems(int currentIndex) async {
    await _resolveSinglePendingItem(currentIndex);
    await _resolveSinglePendingItem(currentIndex + 1);
    await _resolveSinglePendingItem(currentIndex + 2);
  }

  /// Resolves the stream URL for a single item in the playlist.
  ///
  /// [forceResolve] bypasses the `needsUrl` guard, allowing re-resolution of
  /// items whose URL was previously set but has since expired (warm resume).
  Future<void> _resolveSinglePendingItem(
    int index, {
    bool forceResolve = false,
  }) async {
    if (index < 0) return;
    final playlist = _player.state.playlist;
    if (index >= playlist.medias.length) return;
    final media = playlist.medias[index];
    final item = media.extras?['mediaItem'] as MediaItem?;
    // Skip if not pending — unless forceResolve (warm resume with stale URL).
    if (item == null) return;
    if (!forceResolve && item.extras?['needsUrl'] != true) return;

    final videoId = item.extras?['videoId'] as String?;
    if (videoId == null) return;

    // Guard against concurrent resolution of the same videoId.
    // _isResolvingItem is set HERE — before the network await — so that
    // _onPlaylistChanged suppresses intermediate queueIndex emissions for
    // the entire duration of the atomic remove/add/move/jump sequence.
    // Previously this flag was set inside the inner try, after remove() had
    // already fired _onPlaylistChanged with a transient wrong index.
    if (!_pendingResolutions.add(videoId)) return;
    _isResolvingItem = true;
    try {
      final url = await _playVideoIdUseCase.resolveUrl(videoId);

      // Re-validate: index may have shifted or the queue may have changed
      // entirely (e.g. user started a new song while we were awaiting).
      final playlist2 = _player.state.playlist;
      if (index >= playlist2.medias.length) return;
      final currentMedia = playlist2.medias[index];
      final currentItem = currentMedia.extras?['mediaItem'] as MediaItem?;
      if (currentItem?.extras?['videoId'] != videoId) return;
      // Only skip the pending check when forceResolve was requested.
      if (!forceResolve && currentItem?.extras?['needsUrl'] != true) return;

      final updatedItem = (currentItem ?? item).copyWith(
        extras: {...?item.extras, 'url': url, 'needsUrl': false},
      );
      final updatedMedia = Media(
        url,
        extras: {...?currentMedia.extras, 'mediaItem': updatedItem},
      );

      if (_castState?.connectionState == CastConnectionState.connected) {
        if (index == _player.state.playlist.index) {
          final wasPlaying = _player.state.playing;
          if (wasPlaying) await _player.pause();
          _setLocalVolume(0.0);

          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
          await _player.jump(index);

          await _castService?.castMedia(
            url: url,
            title: updatedItem.title,
            artist: updatedItem.artist,
            album: updatedItem.album,
            artworkUrl: updatedItem.artUri?.toString(),
          );

          if (wasPlaying) {
            await _waitForCastSessionState(_castService!, SessionState.playing);
            await _player.play();
          } else {
            await _castService?.pause();
          }
        } else {
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
        }
      } else {
        if (index == _player.state.playlist.index) {
          // Current item: pause → replace → restore position → resume.
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
          // Non-current item: simple in-place replacement, no jump needed.
          await _player.remove(index);
          await _player.add(updatedMedia);
          await _player.move(_player.state.playlist.medias.length - 1, index);
        }
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to resolve URL for item at $index: $e');
    } finally {
      _isResolvingItem = false;
      _pendingResolutions.remove(videoId);
      _syncQueue();
      // Always re-emit the actual current queueIndex and mediaItem after releasing the lock.
      // If the user skipped during resolution, _onPlaylistChanged was suppressed
      // and the new index was never propagated to PlayerNotifier.
      final actualIndex = _player.state.playlist.index;
      if (actualIndex >= 0) {
        playbackState.add(
          playbackState.value.copyWith(queueIndex: actualIndex),
        );
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
    _isStopping = false;
    _playOnInterruptionEnd = false;
    await _restoreCompleter.future.catchError((_) {});
    if (await _requestAudioFocus()) {
      await _player.play();
      if (_castState?.connectionState == CastConnectionState.connected) {
        await _castService?.play();
      }
    }
  }

  @override
  Future<void> pause() => _pause(releaseFocus: true);

  Future<void> _pause({required bool releaseFocus}) async {
    if (releaseFocus) {
      _playOnInterruptionEnd = false;
    }
    await _player.pause();
    if (_castState?.connectionState == CastConnectionState.connected) {
      await _castService?.pause();
    }
    if (releaseFocus) {
      await _releaseAudioFocus();
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
    if (_castState?.connectionState == CastConnectionState.connected) {
      try {
        await _castService?.disconnect();
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
    await _player.stop();
    await _releaseAudioFocus();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    if (_castState?.connectionState == CastConnectionState.connected) {
      await _castService?.seek(position);
    }
  }

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> skipToQueueItem(int index) => _player.jump(index);

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyVolume(1.0);
  }

  void _setLocalVolume(double volume, {bool force = false}) {
    if (!force &&
        _castState?.connectionState == CastConnectionState.connected) {
      _player.setVolume(0.0);
    } else {
      _player.setVolume(volume);
    }
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      _setLocalVolume(v * 100.0);
    }
  }

  Future<void> _waitForCastSessionState(
    SonoraCastService service,
    SessionState targetState, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (service.activeSession?.state == targetState) return;
    final completer = Completer<void>();
    StreamSubscription? sub;
    sub = service.stateStream.listen((state) {
      if (state == targetState) {
        if (!completer.isCompleted) completer.complete();
        sub?.cancel();
      }
    });
    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Timeout fallback
    } finally {
      await sub.cancel();
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

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffle(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
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
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  List<MediaItem> get _currentQueue =>
      _player.state.playlist.medias
          .map((e) => e.extras?['mediaItem'] as MediaItem?)
          .nonNulls
          .toList();

  MediaItem _ensureQueueId(MediaItem item) {
    final existingId = item.extras?['queueId'] as String?;
    final isAlreadyInQueue =
        existingId != null &&
        _currentQueue.any((e) => e.extras?['queueId'] == existingId);

    if (existingId != null && !isAlreadyInQueue) {
      return item;
    }
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    extras['queueId'] =
        '${item.id}_${DateTime.now().microsecondsSinceEpoch}_${_queueIdCounter++}';
    return item.copyWith(extras: extras);
  }

  Media _toMedia(MediaItem item) {
    final updatedItem = _ensureQueueId(item);

    final url = updatedItem.extras?['url'] as String?;
    final videoId = updatedItem.extras?['videoId'] as String? ?? updatedItem.id;
    if (url != null && url.isNotEmpty) {
      return Media(url, extras: {'mediaItem': updatedItem});
    }
    // Unique dummy URI to avoid cache collision
    final dummy = 'http://localhost/dummy_$videoId.wav';
    return Media(dummy, extras: {'mediaItem': updatedItem});
  }

  Future<void> setQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    _isStopping = false;
    final itemsWithKeys = items.map(_ensureQueueId).toList();
    queue.add(itemsWithKeys);
    final playlist = Playlist(
      itemsWithKeys.map(_toMedia).toList(),
      index: initialIndex,
    );
    await _player.open(playlist, play: false);
  }

  Future<void> playNow(List<MediaItem> items, {int initialIndex = 0}) async {
    _isStopping = false;
    final itemsWithKeys = items.map(_ensureQueueId).toList();
    queue.add(itemsWithKeys);
    final playlist = Playlist(
      itemsWithKeys.map(_toMedia).toList(),
      index: initialIndex,
    );
    if (await _requestAudioFocus()) {
      await _player.open(playlist, play: true);
    }
  }

  Future<void> playNext(MediaItem item) async {
    final ci = _player.state.playlist.index;
    final insertAt = (ci + 1).clamp(0, _player.state.playlist.medias.length);
    final media = _toMedia(item);
    _isResolvingItem = true;
    try {
      await _player.add(media);
      await _player.move(_player.state.playlist.medias.length - 1, insertAt);
    } finally {
      _isResolvingItem = false;
      _syncQueue();
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
    await _player.stop();
    await _player.open(const Playlist([]), play: false);
    queue.add([]);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final len = _player.state.playlist.medias.length;

    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;

    // newIndex from onReorderItem is the final target index (already adjusted by Flutter).
    // media_kit's _player.move(from, to) expects 'to' to be the unadjusted index.
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

      final wasPlaying = _player.state.playing;
      final currentPos = _player.state.position;

      _isResolvingItem = true;
      try {
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
      } finally {
        _isResolvingItem = false;
        _syncQueue();
        // Re-emit actual queueIndex in case a skip occurred during retry.
        final actualIndex = _player.state.playlist.index;
        if (actualIndex >= 0) {
          playbackState.add(
            playbackState.value.copyWith(queueIndex: actualIndex),
          );
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
    }
    _isRetrying = false;
  }

  Completer<void> _restoreCompleter = Completer<void>();
  bool _isRestoring = false;
  bool _isResolvingItem = false;

  Future<void> _initRestore() async {
    if (_isRestoring) return;
    _isRestoring = true;
    try {
      final restoreOnStartup = _prefs.getBool('restoreQueueOnStartup') ?? true;
      if (!restoreOnStartup) {
        _restoreCompleter.complete();
        return;
      }

      final rawItems = await _queueRepo.restoreQueue();
      if (rawItems.isEmpty) {
        _restoreCompleter.complete();
        return;
      }

      // ── Cold restore: discard all stale HTTP URLs ────────────────────
      // On a cold resume (kill or long background), YouTube stream URLs are
      // almost certainly expired. Rather than checking each one individually,
      // we mark every HTTP URL as needsUrl so _resolvePendingItems resolves
      // them lazily at play/skip time. Local file:// URLs are kept only if
      // the file still exists on disk.
      final items =
          rawItems.map((item) {
            final url = item.extras?['url'] as String?;
            final isLocalAndValid =
                url != null &&
                url.startsWith('file://') &&
                !UrlStaleness.isStale(url);
            if (isLocalAndValid) return _ensureQueueId(item);
            // Strip the stale URL so _toMedia uses the dummy placeholder and
            // _resolveSinglePendingItem will treat this item as pending.
            return _ensureQueueId(
              item.copyWith(
                extras: {...?item.extras, 'needsUrl': true, 'url': null},
              ),
            );
          }).toList();

      // Emit the queue to the UI immediately — metadata is already available.
      queue.add(items);

      int savedIndex = _prefs.getInt('last_playing_index') ?? 0;
      if (savedIndex < 0 || savedIndex >= items.length) savedIndex = 0;

      // ── Resolve the current item's URL up-front (blocking) ───────────
      // Only this one item needs a fresh URL before the player opens;
      // all others will be resolved lazily by _resolvePendingItems as
      // the user plays/skips through the queue.
      var currentItem = items[savedIndex];
      try {
        final freshUrl = await _playVideoIdUseCase.resolveUrl(currentItem.id);
        currentItem = currentItem.copyWith(
          extras: {...?currentItem.extras, 'url': freshUrl, 'needsUrl': false},
        );
        items[savedIndex] = currentItem;
      } catch (e) {
        // URL resolution failed; the item remains needsUrl: true.
        // _onPlayerError will handle the retry when the user presses play.
        dev.log(
          '[AudioHandler] Cold restore: failed to resolve URL for index $savedIndex: $e',
        );
      }

      final savedPosMs = _prefs.getInt('last_playing_position_ms') ?? 0;

      // ── Open the player with the clean, rebuilt playlist ─────────────
      _isStopping = false;
      final playlist = Playlist(
        items.map(_toMedia).toList(),
        index: savedIndex,
      );
      await _player.open(playlist, play: false);

      if (savedPosMs > 0) {
        // Wait for the media to load so the seek is not silently ignored.
        for (int i = 0; i < 30; i++) {
          if (_player.state.duration > Duration.zero) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        await _player.seek(Duration(milliseconds: savedPosMs));
      }
      // _onPlaylistChanged will fire after _player.open and call
      // _resolvePendingItems to eagerly resolve indices +1 and +2.
    } catch (e, stack) {
      dev.log('[AudioHandler] Error in _initRestore: $e\n$stack');
    } finally {
      _isRestoring = false;
      if (!_restoreCompleter.isCompleted) {
        _restoreCompleter.complete();
      }
    }
  }

  Future<void> persistQueue(List<MediaItem> items) async {
    await _queueRepo.persistQueue(items);
  }

  /// Resumes playback state after the app returns to the foreground.
  ///
  /// Two modes:
  /// - **Warm resume**: the OS kept the process alive and the player playlist
  ///   is intact. Only the current item's URL is re-checked; if stale it is
  ///   silently re-resolved.
  /// - **Cold resume**: the process was killed and the player is rebuilt from
  ///   the DB snapshot. All HTTP stream URLs are discarded and resolved lazily —
  ///   only the current item's URL is resolved up-front so playback can resume
  ///   immediately.
  Future<void> restoreIfNeeded() async {
    if (_isRestoring || _player.state.playing) return;

    final playlistEmpty = _player.state.playlist.medias.isEmpty;
    // We only treat it as a cold restore if the player has been cleared
    // (e.g. process killed and restarted). If the playlist is still there,
    // we perform a warm resume regardless of how much time has passed,
    // as it is much faster and less disruptive.
    final isCold = playlistEmpty;

    if (!isCold) {
      // ── Warm resume: only re-check the current item's URL ──────────
      // With battery optimization disabled the process stays alive, so
      // playlistEmpty is almost always false. For in-memory playlists, we
      // only re-resolve the current item if its URL has expired.
      final currentIndex = _player.state.playlist.index;
      final medias = _player.state.playlist.medias;
      if (currentIndex >= 0 && currentIndex < medias.length) {
        final item = medias[currentIndex].extras?['mediaItem'] as MediaItem?;
        final url = item?.extras?['url'] as String?;
        if (UrlStaleness.isStale(url)) {
          // forceResolve: true bypasses the needsUrl guard because this item
          // was previously resolved (no needsUrl flag) but its URL has expired.
          unawaited(
            _resolveSinglePendingItem(currentIndex, forceResolve: true),
          );
        }
      }
      return;
    }

    // ── Cold resume: full rebuild from DB ────────────────────────────
    _pendingResolutions.clear();
    if (_restoreCompleter.isCompleted) {
      _restoreCompleter = Completer<void>();
    }
    await _initRestore();
  }

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
    _playerErrorSub?.cancel();
    _onPlayErrorController.close();
    _player.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — getChildren (AA browse tree)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    dev.log('[AA] getChildren: "$parentMediaId"');
    // audio_service returns BrowserRoot("/") to AA, so the root parentMediaId is "/"
    final isRoot =
        parentMediaId == _rootId ||
        parentMediaId == 'root' ||
        parentMediaId == 'root_id' ||
        parentMediaId.isEmpty;
    try {
      if (isRoot) return _buildRootChildren();

      switch (parentMediaId) {
        // Top-level
        case _homeId:
          return _buildHomeChildren();
        case _libraryId:
          return _buildLibraryChildren();

        // Library sub-nodes
        case _recentId:
          return _buildRecentChildren();
        case _likedId:
          return _buildLikedChildren();
        case _playlistsId:
          return _buildPlaylistFolders();
        case _artistsId:
          return _buildArtistFolders();
        case _albumsId:
          return _buildLikedAlbumFolders();
        case _historyId:
          return _buildRecentChildren();

        // Dynamic prefixes
        default:
          if (parentMediaId.startsWith(_homeSectionPrefix)) {
            return _buildHomeSectionChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_playlistPrefix)) {
            return _buildPlaylistEntryChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_artistPrefix)) {
            return _buildArtistChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homeAlbumPrefix)) {
            return _buildHomeAlbumSongChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homePlaylistPrefix)) {
            return _buildHomePlaylistVideoChildren(parentMediaId);
          }
          return [];
      }
    } catch (e, st) {
      dev.log('[AA] getChildren error for "$parentMediaId": $e\n$st');
      return [];
    }
  }

  List<MediaItem> _buildRootChildren() {
    return [
      MediaItem(
        id: _homeId,
        title: 'Home',
        displaySubtitle: 'Homepage',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _libraryId,
        title: 'Library',
        displaySubtitle: 'Your music',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
    ];
  }

  Future<List<MediaItem>> _buildLibraryChildren() async {
    final likedFuture = _libraryRepo.getAllLikedSongs();
    final artistsFuture = _libraryRepo.getAllFollowedArtists();
    final playlistsFuture = _libraryRepo.getAllPlaylists();
    final albumsFuture = _libraryRepo.getAllLikedAlbums();
    final historyFuture = _libraryRepo.getRecentHistory(limit: 50);
    final liked = await likedFuture;
    final artists = await artistsFuture;
    final playlists = await playlistsFuture;
    final albums = await albumsFuture;
    final history = await historyFuture;

    final items = <MediaItem>[];

    void addSection(String id, String title, List<MediaItem> sectionItems) {
      if (sectionItems.isEmpty) return;
      items.add(
        MediaItem(
          id: id,
          title: title,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(sectionItems.take(3));
    }

    addSection(
      _likedId,
      'Favorites',
      liked
          .map(
            (s) => MediaItem(
              id: s.videoId,
              title: s.title,
              artist: s.artist,
              artUri:
                  s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          )
          .toList(),
    );

    addSection(
      _artistsId,
      'Artists',
      artists
          .map(
            (a) => MediaItem(
              id: '$_artistPrefix${a.artistId}',
              title: a.name,
              artUri:
                  a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          )
          .toList(),
    );

    addSection(
      _playlistsId,
      'Playlists',
      playlists
          .map(
            (p) => MediaItem(
              id: '$_playlistPrefix${p.id}',
              title: p.name,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          )
          .toList(),
    );

    addSection(
      _albumsId,
      'Albums',
      albums
          .map(
            (a) => MediaItem(
              id: '$_homeAlbumPrefix${a.albumId}',
              title: a.name,
              artist: a.artistName,
              artUri:
                  a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          )
          .toList(),
    );

    addSection(
      _historyId,
      'History',
      history
          .map(
            (h) => MediaItem(
              id: h.videoId,
              title: h.title,
              artist: h.artist,
              artUri:
                  h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          )
          .toList(),
    );

    return items;
  }

  Future<List<MediaItem>> _buildHomeChildren() async {
    final result = await _musicRepo.getHome();
    final sections = result.sections;
    dev.log('[AA] getHome returned ${sections.length} sections');
    final items = <MediaItem>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (section.contents.isEmpty) continue;
      final sectionItems =
          section.contents.expand(_contentToMediaItems).toList();
      if (sectionItems.isEmpty) continue;
      // Section header — browsable, clicking shows all items
      items.add(
        MediaItem(
          id: '$_homeSectionPrefix$i',
          title: section.title,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      // First 5 items shown inline on this level
      items.addAll(sectionItems.take(3));
    }
    return items;
  }

  List<MediaItem> _contentToMediaItems(dynamic content) {
    if (content is SongDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          album: content.album?.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': content.type == 'VIDEO',
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is VideoDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': true,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is AlbumDetailed) {
      return [
        MediaItem(
          id: '$_homeAlbumPrefix${content.albumId}',
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is PlaylistDetailed) {
      return [
        MediaItem(
          id: '$_homePlaylistPrefix${content.playlistId}',
          title: content.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    }
    return [];
  }

  Future<List<MediaItem>> _buildHomeSectionChildren(
    String parentMediaId,
  ) async {
    final index = int.tryParse(
      parentMediaId.substring(_homeSectionPrefix.length),
    );
    if (index == null) return [];
    final result = await _musicRepo.getHome();
    final sections = result.sections;
    if (index >= sections.length) return [];
    final section = sections[index];
    return section.contents.expand(_contentToMediaItems).toList();
  }

  Future<List<MediaItem>> _buildRecentChildren() async {
    final history = await _libraryRepo.getRecentHistory(limit: 50);
    return history
        .map(
          (h) => MediaItem(
            id: h.videoId,
            title: h.title,
            artist: h.artist,
            artUri:
                h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
            extras: {
              'needsUrl': true,
              'videoId': h.videoId,
              'isVideo': h.isVideo,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildLikedChildren() async {
    final songs = await _libraryRepo.getAllLikedSongs();
    return songs
        .map(
          (s) => MediaItem(
            id: s.videoId,
            title: s.title,
            artist: s.artist,
            artUri:
                s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
            extras: {
              'needsUrl': true,
              'videoId': s.videoId,
              'isVideo': s.isVideo,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistFolders() async {
    final playlists = await _libraryRepo.getAllPlaylists();
    return playlists
        .map(
          (p) => MediaItem(
            id: '$_playlistPrefix${p.id}',
            title: p.name,
            displaySubtitle: 'Playlist',
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistEntryChildren(
    String parentMediaId,
  ) async {
    final playlistId = int.parse(
      parentMediaId.substring(_playlistPrefix.length),
    );
    final entries = await _libraryRepo.getPlaylistEntries(playlistId);
    final playlistIdStr = playlistId.toString();

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayPlaylist$playlistIdStr',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistIdStr',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    for (final entry in entries) {
      final liked = await _libraryRepo.getLikedSong(entry.videoId);
      final title = liked?.title ?? entry.title ?? entry.videoId;
      final artist = liked?.artist ?? entry.artist ?? '';
      final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      items.add(
        MediaItem(
          id: entry.videoId,
          title: title,
          artist: artist,
          artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl) : null,
          duration: const Duration(seconds: 0),
          extras: {
            'needsUrl': true,
            'videoId': entry.videoId,
            'isVideo': liked?.isVideo ?? entry.isVideo,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }
    return items;
  }

  Future<List<MediaItem>> _buildArtistFolders() async {
    final artists = await _libraryRepo.getAllFollowedArtists();
    return artists
        .map(
          (a) => MediaItem(
            id: '$_artistPrefix${a.artistId}',
            title: a.name,
            displaySubtitle: 'Artist',
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildArtistChildren(String parentMediaId) async {
    final artistId = parentMediaId.substring(_artistPrefix.length);
    final artistInfo = await _musicRepo.getArtist(artistId);
    final followed = await _libraryRepo.getFollowedArtist(artistId);

    final mediaItems = <MediaItem>[
      MediaItem(
        id: '$_actionPlayArtist$artistId',
        title: 'Play Top Songs',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleArtist$artistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionFollowArtist$artistId',
        title: followed != null ? 'Following' : 'Follow',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    // 1. Top Songs (Playable)
    for (final song in artistInfo.topSongs) {
      mediaItems.add(
        MediaItem(
          id: song.videoId,
          title: song.name,
          artist: song.artist.name,
          artUri:
              song.thumbnails.isNotEmpty
                  ? Uri.tryParse(song.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: song.duration ?? 0),
          playable: true,
          extras: {_kContentStylePlayable: _kStyleList},
        ),
      );
    }

    // 2. Albums (Browsable folders)
    for (final album in artistInfo.topAlbums) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${album.albumId}',
          title: album.name,
          artist: 'Album',
          artUri:
              album.thumbnails.isNotEmpty
                  ? Uri.tryParse(album.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 3. Singles (Browsable folders)
    for (final single in artistInfo.topSingles) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${single.albumId}',
          title: single.name,
          artist: 'Single',
          artUri:
              single.thumbnails.isNotEmpty
                  ? Uri.tryParse(single.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 4. Featured On (Playlists - Browsable folders)
    for (final playlist in artistInfo.featuredOn) {
      mediaItems.add(
        MediaItem(
          id: '$_homePlaylistPrefix${playlist.playlistId}',
          title: playlist.name,
          artist: 'Playlist',
          artUri:
              playlist.thumbnails.isNotEmpty
                  ? Uri.tryParse(playlist.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 5. Similar Artists (Browsable folders)
    for (final related in artistInfo.similarArtists) {
      mediaItems.add(
        MediaItem(
          id: '$_artistPrefix${related.artistId}',
          title: related.name,
          artist: 'Artist',
          artUri:
              related.thumbnails.isNotEmpty
                  ? Uri.tryParse(related.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    return mediaItems;
  }

  Future<List<MediaItem>> _buildLikedAlbumFolders() async {
    final albums = await _libraryRepo.getAllLikedAlbums();
    return albums
        .map(
          (a) => MediaItem(
            id: '$_homeAlbumPrefix${a.albumId}',
            title: a.name,
            artist: a.artistName,
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildHomeAlbumSongChildren(
    String parentMediaId,
  ) async {
    final albumId = parentMediaId.substring(_homeAlbumPrefix.length);
    final album = await _musicRepo.getAlbum(albumId);
    final liked = await _libraryRepo.getLikedAlbum(albumId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayAlbum$albumId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleAlbum$albumId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikeAlbum$albumId',
        title: liked != null ? 'Unlike Album' : 'Like Album',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      album.songs
          .take(100)
          .map(
            (s) => MediaItem(
              id: s.videoId,
              title: s.name,
              artist: s.artist.name,
              album: album.name,
              artUri:
                  album.thumbnails.isNotEmpty
                      ? Uri.tryParse(album.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: s.duration ?? 0),
              extras: {
                'needsUrl': true,
                'videoId': s.videoId,
                'isVideo': s.type == 'VIDEO',
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
  }

  Future<List<MediaItem>> _buildHomePlaylistVideoChildren(
    String parentMediaId,
  ) async {
    final playlistId = parentMediaId.substring(_homePlaylistPrefix.length);
    final videos = await _musicRepo.getPlaylistVideos(playlistId);
    final liked = await _libraryRepo.getLikedPlaylist(playlistId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayPlaylist$playlistId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikePlaylist$playlistId',
        title: liked != null ? 'Unlike Playlist' : 'Like Playlist',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      videos
          .take(100)
          .map(
            (v) => MediaItem(
              id: v.videoId,
              title: v.name,
              artist: v.artist.name,
              artUri:
                  v.thumbnails.isNotEmpty
                      ? Uri.tryParse(v.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: v.duration ?? 0),
              extras: {
                'needsUrl': true,
                'videoId': v.videoId,
                'isVideo': true,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromMediaId
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      // ── Album actions ────────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayAlbum)) {
        final albumId = mediaId.substring(_actionPlayAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final items = await _playAlbumUseCase.execute(album.songs);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleAlbum)) {
        final albumId = mediaId.substring(_actionShuffleAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final shuffled = List<SongDetailed>.from(album.songs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionLikeAlbum)) {
        final albumId = mediaId.substring(_actionLikeAlbum.length);
        final existing = await _libraryRepo.getLikedAlbum(albumId);
        if (existing != null) {
          await _libraryRepo.deleteLikedAlbum(albumId);
        } else {
          final album = await _musicRepo.getAlbum(albumId);
          await _libraryRepo.toggleLikedAlbum(
            LikedAlbumModel(
              albumId: albumId,
              name: album.name,
              artistName: album.artist.name,
              thumbnailUrl:
                  album.thumbnails.isNotEmpty
                      ? album.thumbnails.last.url
                      : null,
              year: album.year,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homeAlbumPrefix$albumId',
          ),
        );
        return;
      }

      // ── Artist actions ───────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayArtist)) {
        final artistId = mediaId.substring(_actionPlayArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final items = await _playAlbumUseCase.execute(artist.topSongs);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleArtist)) {
        final artistId = mediaId.substring(_actionShuffleArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final shuffled = List<SongDetailed>.from(artist.topSongs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionFollowArtist)) {
        final artistId = mediaId.substring(_actionFollowArtist.length);
        final existing = await _libraryRepo.getFollowedArtist(artistId);
        if (existing != null) {
          await _libraryRepo.deleteFollowedArtist(artistId);
        } else {
          final artist = await _musicRepo.getArtist(artistId);
          await _libraryRepo.toggleFollowedArtist(
            FollowedArtistModel(
              artistId: artistId,
              name: artist.name,
              thumbnailUrl:
                  artist.thumbnails.isNotEmpty
                      ? artist.thumbnails.last.url
                      : null,
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_artistPrefix$artistId',
          ),
        );
        return;
      }

      // ── Playlist actions ─────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayPlaylist)) {
        final playlistId = mediaId.substring(_actionPlayPlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          // Local playlist — read entries from DB
          final entries = await _libraryRepo.getPlaylistEntries(localId);
          final items = <MediaItem>[];
          for (final entry in entries) {
            final liked = await _libraryRepo.getLikedSong(entry.videoId);
            final title = liked?.title ?? entry.title ?? entry.videoId;
            final artist = liked?.artist ?? entry.artist ?? '';
            final thumbUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
            items.add(
              MediaItem(
                id: entry.videoId,
                title: title,
                artist: artist,
                artUri: thumbUrl != null ? Uri.tryParse(thumbUrl) : null,
                extras: {
                  'needsUrl': true,
                  'videoId': entry.videoId,
                  'isVideo': liked?.isVideo ?? entry.isVideo,
                  _kContentStylePlayable: _kStyleList,
                },
              ),
            );
          }
          if (items.isNotEmpty) {
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items[0] = items.first.copyWith(
                extras: {...items.first.extras!, 'url': url, 'needsUrl': false},
              );
            } catch (_) {}
          }
          await playNow(items);
        } else {
          // YT Music playlist — fetch videos from API
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final items = await _playPlaylistUseCase.execute(videos);
          await playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionShufflePlaylist)) {
        final playlistId = mediaId.substring(_actionShufflePlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          // Local playlist — read entries from DB
          final entries = await _libraryRepo.getPlaylistEntries(localId);
          var items = <MediaItem>[];
          for (final entry in entries) {
            final liked = await _libraryRepo.getLikedSong(entry.videoId);
            final title = liked?.title ?? entry.title ?? entry.videoId;
            final artist = liked?.artist ?? entry.artist ?? '';
            final thumbUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
            items.add(
              MediaItem(
                id: entry.videoId,
                title: title,
                artist: artist,
                artUri: thumbUrl != null ? Uri.tryParse(thumbUrl) : null,
                extras: {
                  'needsUrl': true,
                  'videoId': entry.videoId,
                  'isVideo': liked?.isVideo ?? entry.isVideo,
                  _kContentStylePlayable: _kStyleList,
                },
              ),
            );
          }
          if (items.isNotEmpty) {
            items = List<MediaItem>.from(items)..shuffle();
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items[0] = items.first.copyWith(
                extras: {...items.first.extras!, 'url': url, 'needsUrl': false},
              );
            } catch (_) {}
          }
          await playNow(items);
        } else {
          // YT Music playlist — fetch videos from API
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final shuffled = List<VideoDetailed>.from(videos)..shuffle();
          final items = await _playPlaylistUseCase.execute(shuffled);
          await playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionLikePlaylist)) {
        final playlistId = mediaId.substring(_actionLikePlaylist.length);
        final existing = await _libraryRepo.getLikedPlaylist(playlistId);
        if (existing != null) {
          await _libraryRepo.deleteLikedPlaylist(playlistId);
        } else {
          // Fetch playlist metadata — getPlaylist for YT Music playlists
          final playlist = await _musicRepo.getPlaylist(playlistId);
          await _libraryRepo.toggleLikedPlaylist(
            LikedPlaylistModel(
              playlistId: playlistId,
              name: playlist.name,
              thumbnailUrl:
                  playlist.thumbnails.isNotEmpty
                      ? playlist.thumbnails.last.url
                      : null,
              videoCount: playlist.videoCount,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homePlaylistPrefix$playlistId',
          ),
        );
        return;
      }

      // ── Default: single song play ───────────────────────────
      final item = await _playVideoIdUseCase.execute(mediaId);
      await playNow([item]);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — search (FAB / text search → list of results)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      // Esegue le ricerche filtrate in parallelo per ottenere risultati ricchi e completi
      // invece della ricerca mista (che restituisce pochi elementi condensati).
      final futureArtists = _musicRepo.searchArtists(query);
      final futureSongs = _musicRepo.searchSongs(query);
      final futureAlbums = _musicRepo.searchAlbums(query);
      final futurePlaylists = _musicRepo.searchPlaylists(query);

      final results = await Future.wait([
        futureArtists,
        futureSongs,
        futureAlbums,
        futurePlaylists,
      ]);

      final artistsData = results[0];
      final songsData = results[1];
      final albumsData = results[2];
      final playlistsData = results[3];

      final artists = <MediaItem>[];
      final songs = <MediaItem>[];
      final albums = <MediaItem>[];
      final playlists = <MediaItem>[];

      // Mappatura Artisti
      for (final result in artistsData) {
        if (result is ArtistDetailed) {
          artists.add(
            MediaItem(
              id: '$_artistPrefix${result.artistId}',
              title: result.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Canzoni (e Video se presenti)
      for (final result in songsData) {
        if (result is SongDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          );
        } else if (result is VideoDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          );
        }
      }

      // Mappatura Album
      for (final result in albumsData) {
        if (result is AlbumDetailed) {
          albums.add(
            MediaItem(
              id: '$_homeAlbumPrefix${result.albumId}',
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Playlist
      for (final result in playlistsData) {
        if (result is PlaylistDetailed) {
          playlists.add(
            MediaItem(
              id: '$_homePlaylistPrefix${result.playlistId}',
              title: result.name,
              // Le API delle playlist specifiche non sempre espongono author.name facilmente
              // ma possiamo ometterlo e mostrare la thumbnail/titolo in Android Auto
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Ritorna la lista unita con priorità logica: Artisti > Canzoni > Album > Playlist
      return [...artists, ...songs, ...albums, ...playlists];
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromSearch
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final results = await _musicRepo.searchSongs(query);
      if (results.isEmpty) return;
      final item = await _playVideoIdUseCase.execute(results.first.videoId);
      await playNow([item]);
    } catch (_) {}
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
          isVideo: current?.extras?['isVideo'] == true,
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
            isVideo: item.extras?['isVideo'] == true,
          ),
        );

      case _actionSleepTimer:
        break;
    }
    return null;
  }
}
