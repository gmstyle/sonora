import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/audio_handler.dart';
import 'library_notifier.dart';
import 'play_video_id_use_case_provider.dart';
import 'play_album_use_case_provider.dart';
import 'play_playlist_use_case_provider.dart';
import 'play_smart_mix_use_case_provider.dart';
import 'queue_use_case_provider.dart';
import 'settings_provider.dart';
import 'start_radio_use_case_provider.dart';

// Re-export for convenience so UI layers don't need to import audio_handler.
export '../features/player/audio_handler.dart' show RestoreStatus;

final audioHandlerProvider = Provider<SonoraAudioHandler>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final playerStateProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

enum PlayerSubView { none, lyrics, queue }

class PlayerSubViewNotifier extends Notifier<PlayerSubView> {
  @override
  PlayerSubView build() => PlayerSubView.none;

  void set(PlayerSubView view) {
    state = view;
  }
}

final playerSubViewProvider =
    NotifierProvider<PlayerSubViewNotifier, PlayerSubView>(
      PlayerSubViewNotifier.new,
    );

class PlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isSwitching;

  /// True while the audio handler is rebuilding the player from the persisted
  /// queue (i.e. [RestoreStatus.restoring]).  When true the UI must:
  ///   • show a loading spinner on the play/pause button
  ///   • disable seek, skip, and play/pause interactions
  ///   • show [position] as a static value (the saved position from disk)
  ///   • show the shimmer on the mini-player bar
  final bool isRestoring;

  final bool isPaused;
  final bool hasError;
  final String? errorMessage;
  final MediaItem? currentSong;
  final List<MediaItem> queue;
  final int currentIndex;
  final Duration position;
  final Duration duration;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final Duration? sleepTimerRemaining;

  const PlayerState({
    this.isPlaying = false,
    this.isLoading = false,
    this.isSwitching = false,
    this.isRestoring = false,
    this.isPaused = false,
    this.hasError = false,
    this.errorMessage,
    this.currentSong,
    this.queue = const [],
    this.currentIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleMode = AudioServiceShuffleMode.none,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.sleepTimerRemaining,
  });

  bool get isVideo => currentSong?.extras?['isVideo'] == true;

  /// True when the player is blocked for any reason: active restore, or a
  /// user-initiated song switch in progress.  Use this in the UI to gate all
  /// interactive controls at once.
  bool get isBlocked => isRestoring || isSwitching;

  PlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isSwitching,
    bool? isRestoring,
    bool? isPaused,
    bool? hasError,
    String? errorMessage,
    MediaItem? currentSong,
    List<MediaItem>? queue,
    int? currentIndex,
    Duration? position,
    Duration? duration,
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
    Duration? sleepTimerRemaining,
    bool clearError = false,
    bool clearSleepTimer = false,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isSwitching: isSwitching ?? this.isSwitching,
      isRestoring: isRestoring ?? this.isRestoring,
      isPaused: isPaused ?? this.isPaused,
      hasError: hasError ?? this.hasError,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      repeatMode: repeatMode ?? this.repeatMode,
      sleepTimerRemaining:
          clearSleepTimer
              ? null
              : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> with WidgetsBindingObserver {
  SonoraAudioHandler get _handler => ref.read(audioHandlerProvider);

  StreamSubscription? _playbackSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playErrorSub;
  StreamSubscription? _restoreStatusSub;
  bool _isFetchingUpNext = false;
  int _operationVersion = 0;
  Timer? _sleepTimer;
  Timer? _sleepTimerTick;
  DateTime? _sleepTimerStart;
  Duration? _sleepTimerDuration;
  bool _isReordering = false;

  @override
  PlayerState build() {
    WidgetsBinding.instance.addObserver(this);

    var initialState = const PlayerState();

    // Seed initial state from handler synchronously to ensure it is fully
    // populated before any widgets or listeners read it.
    final s = _handler.playbackState.valueOrNull;
    final item = _handler.mediaItem.valueOrNull;
    final items = _handler.queue.valueOrNull;

    if (s != null) {
      initialState = initialState.copyWith(
        isPlaying: s.playing,
        isPaused: !s.playing && s.processingState == AudioProcessingState.ready,
        isLoading:
            s.processingState == AudioProcessingState.loading ||
            s.processingState == AudioProcessingState.buffering,
        hasError: s.processingState == AudioProcessingState.error,
        currentIndex: s.queueIndex ?? 0,
        shuffleMode: s.shuffleMode,
        repeatMode: s.repeatMode,
      );
    }
    if (item != null) {
      initialState = initialState.copyWith(currentSong: item);
    }
    if (items != null) {
      initialState = initialState.copyWith(queue: items);
    }

    if (_handler.currentRestoreStatus == RestoreStatus.restoring) {
      initialState = initialState.copyWith(
        isRestoring: true,
        position: _handler.savedPosition,
      );
    }

    var isDisposed = false;
    ref.onDispose(() {
      isDisposed = true;
      WidgetsBinding.instance.removeObserver(this);
      _playbackSub?.cancel();
      _mediaItemSub?.cancel();
      _queueSub?.cancel();
      _durationSub?.cancel();
      _positionSub?.cancel();
      _playErrorSub?.cancel();
      _restoreStatusSub?.cancel();
      _sleepTimer?.cancel();
      _sleepTimerTick?.cancel();
    });

    // Defer stream subscriptions to a microtask so that any synchronous initial
    // emissions do not trigger state modifications during the provider's build phase.
    Future.microtask(() {
      if (isDisposed) return;

      _restoreStatusSub = _handler.restoreStatusStream.listen((status) {
        if (status == RestoreStatus.restoring) {
          state = state.copyWith(
            isRestoring: true,
            position: _handler.savedPosition,
          );
        } else {
          state = state.copyWith(isRestoring: false);
        }
      });

      _positionSub = _handler.positionStream.listen((pos) {
        // Don't overwrite the static saved position while restoring.
        if (!state.isRestoring) state = state.copyWith(position: pos);
      });

      _playbackSub = _handler.playbackState.listen((s) {
        final wasSwitching = state.isSwitching;
        state = state.copyWith(
          isPlaying: s.playing,
          isPaused:
              !s.playing && s.processingState == AudioProcessingState.ready,
          isLoading:
              s.processingState == AudioProcessingState.loading ||
              s.processingState == AudioProcessingState.buffering,
          hasError: s.processingState == AudioProcessingState.error,
          // position is now tracked via positionStream — skip here to avoid
          // overwriting the more frequent update with a stale value from
          // playbackState (which is no longer updated on every tick).
          currentIndex: s.queueIndex ?? 0,
          shuffleMode: s.shuffleMode,
          repeatMode: s.repeatMode,
          // Keep isSwitching true while the player is paused during a user-
          // initiated song change (e.g. after pause() in playNow/skipToIndex),
          // so the mini-player keeps showing the loading shimmer until the new
          // track is actually playing.
          isSwitching:
              wasSwitching &&
                      !(s.processingState == AudioProcessingState.ready &&
                          s.playing)
                  ? true
                  : false,
        );

        if (s.processingState == AudioProcessingState.ready && s.playing) {
          state = state.copyWith(isSwitching: false);
          // Clear transient error message from failed retry
          if (state.errorMessage != null) {
            state = state.copyWith(clearError: true);
          }
        }

        if (s.processingState == AudioProcessingState.ready && s.playing) {
          // Use wasSwitching (captured before state update) so this block never
          // fires on the very first ready event of a user-initiated song change.
          // On the next event (e.g. position tick) wasSwitching is already false
          // and the prefetch is allowed to run.
          // Up-next is only meaningful when the queue is not set to repeat.
          if (state.repeatMode == AudioServiceRepeatMode.none &&
              state.currentIndex >= state.queue.length - 1 &&
              !wasSwitching &&
              !_isFetchingUpNext &&
              ref.read(settingsProvider).autoPlayUpNext) {
            _isFetchingUpNext = true;
            _prefetchAutoPlayUpNext();
          }
        }

        if (s.processingState == AudioProcessingState.completed &&
            !_isFetchingUpNext &&
            state.queue.isNotEmpty) {
          final v = _operationVersion;
          if (state.shuffleMode == AudioServiceShuffleMode.all) {
            final len = state.queue.length;
            if (len > 1) {
              final random = Random();
              var nextIndex = state.currentIndex;
              while (nextIndex == state.currentIndex) {
                nextIndex = random.nextInt(len);
              }
              _handler.skipToQueueItem(nextIndex).then((_) async {
                if (_operationVersion == v) await _handler.play();
              });
            }
          } else if (state.currentIndex < state.queue.length - 1) {
            // Already have upcoming items (e.g. prefetched up-next). Skip to
            // the next one instead of fetching again, which prevents duplicates.
            _handler.skipToQueueItem(state.currentIndex + 1).then((_) async {
              if (_operationVersion == v) await _handler.play();
            });
          } else if (state.repeatMode == AudioServiceRepeatMode.none &&
              ref.read(settingsProvider).autoPlayUpNext) {
            _isFetchingUpNext = true;
            _fetchAutoPlayUpNext();
          }
        }
      });

      _mediaItemSub = _handler.mediaItem.listen((item) {
        state = state.copyWith(currentSong: item);
        if (item != null && ref.read(settingsProvider).trackHistory) {
          ref
              .read(libraryNotifierProvider.notifier)
              .recordPlay(
                item.id,
                item.title,
                item.artist ?? 'Unknown Artist',
                thumbnailUrl: item.artUri?.toString(),
                duration: item.duration?.inSeconds,
                isVideo: item.extras?['isVideo'] == true,
                isExplicit: item.extras?['isExplicit'] == true,
              );
        }
      });

      _queueSub = _handler.queue.listen((items) {
        if (_isReordering) return;
        final currentQueue = state.queue;
        final queueChanged =
            currentQueue.length != items.length ||
            !const ListEquality().equals(
              currentQueue
                  .map((e) => e.extras?['queueId'] as String? ?? e.id)
                  .toList(),
              items
                  .map((e) => e.extras?['queueId'] as String? ?? e.id)
                  .toList(),
            );
        if (queueChanged) {
          state = state.copyWith(queue: items);
        }

        // isSwitching is true during playSong/playVideoId/playQueue while the new
        // queue is being set up. Skipping here prevents a spurious prefetch when
        // state.currentIndex still holds the old (larger) index from the previous
        // queue and state.isPlaying hasn't been updated yet from the pending
        // pause() stream event.
        // Up-next is only meaningful when the queue is not set to repeat.
        if (state.repeatMode == AudioServiceRepeatMode.none &&
            state.currentIndex >= items.length - 1 &&
            state.isPlaying &&
            !state.isSwitching &&
            !_isFetchingUpNext &&
            ref.read(settingsProvider).autoPlayUpNext) {
          _isFetchingUpNext = true;
          _prefetchAutoPlayUpNext();
        }
      });

      _durationSub = _handler.durationStream.listen((d) {
        state = state.copyWith(duration: d);
      });

      _playErrorSub = _handler.onPlayError.listen((error) {
        state = state.copyWith(
          hasError: true,
          errorMessage: 'Failed to play ${error.$2}',
        );
      });
    });

    _handler.setCrossfadeDuration(ref.read(settingsProvider).crossfadeDuration);
    ref.listen(settingsProvider, (prev, next) {
      if (prev?.crossfadeDuration != next.crossfadeDuration) {
        _handler.setCrossfadeDuration(next.crossfadeDuration);
      }
    });

    return initialState;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handler.restoreIfNeeded();
    }
  }

  /// Fallback triggered when the current track has already finished
  /// (processingState == completed). It fetches related content, appends it
  /// to the queue and immediately skips to the first new item so playback
  /// never stalls. Used as a safety net when the background prefetch has
  /// not completed in time.
  ///
  /// Guards _operationVersion after every await so that if the user taps a
  /// new song while this is running, we abort before touching skipToQueueItem
  /// or play() – preventing a race that would leave the player stuck loading.
  ///
  /// Only the first up-next item has its stream URL resolved immediately.
  /// Remaining items are added as pending ([needsUrl]) — the player resolves
  /// their URLs lazily when they are about to play.
  Future<void> _fetchAutoPlayUpNext() async {
    try {
      final lastItem = state.currentSong;
      if (lastItem == null) return;
      final v = _operationVersion;

      final radioUseCase = ref.read(startRadioUseCaseProvider);
      final result = await radioUseCase.execute(lastItem.id);
      if (_operationVersion != v) return;

      final firstItem = result.firstItem;
      final oldLength = state.queue.length;
      await _handler.addToQueue(firstItem);
      if (_operationVersion != v) return;

      await _handler.skipToQueueItem(oldLength);
      if (_operationVersion != v) return;

      await _handler.play();

      if (result.remaining.isNotEmpty) {
        final pendingItems = radioUseCase.toPendingItems(result.remaining);
        if (_operationVersion != v) return;
        await _handler.addAllToQueue(pendingItems);
      }
    } catch (_) {
    } finally {
      _isFetchingUpNext = false;
    }
  }

  Future<void> _prefetchAutoPlayUpNext() async {
    try {
      final seedItem = state.currentSong;
      if (seedItem == null) return;
      final seedId = seedItem.id;

      final radioUseCase = ref.read(startRadioUseCaseProvider);
      final result = await radioUseCase.execute(seedId, resolveFirstUrl: false);
      if (state.currentSong?.id != seedId) return;

      await _handler.addToQueue(result.firstItem);
      if (state.currentSong?.id != seedId) return;

      if (result.remaining.isNotEmpty) {
        final pendingItems = radioUseCase.toPendingItems(result.remaining);
        if (state.currentSong?.id != seedId) return;
        await _handler.addAllToQueue(pendingItems);
      }
    } catch (_) {
    } finally {
      _isFetchingUpNext = false;
    }
  }

  // ── API mutazione coda ────────────────────────────────────────

  Future<void> playNow(List<MediaItem> items, {int initialIndex = 0}) async {
    ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      await _handler.playNow(items, initialIndex: initialIndex);
    } catch (e) {
      state = state.copyWith(
        isSwitching: false,
        hasError: true,
        errorMessage: 'Failed to start playback: $e',
      );
    }
  }

  Future<void> playAlbum(List<SongDetailed> songs, {int startIndex = 0}) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      final useCase = ref.read(playAlbumUseCaseProvider);
      final items = await useCase.execute(songs, playIndex: startIndex);
      if (_operationVersion != v) return;
      await _handler.playNow(items, initialIndex: startIndex);
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          isSwitching: false,
          hasError: true,
          errorMessage: 'Failed to play album: $e',
        );
      }
    }
  }

  Future<void> playPlaylist(
    List<VideoDetailed> videos, {
    int startIndex = 0,
  }) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      final useCase = ref.read(playPlaylistUseCaseProvider);
      final items = await useCase.execute(videos, playIndex: startIndex);
      if (_operationVersion != v) return;
      await _handler.playNow(items, initialIndex: startIndex);
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          isSwitching: false,
          hasError: true,
          errorMessage: 'Failed to play playlist: $e',
        );
      }
    }
  }

  Future<void> playSmartMix(List<dynamic> songs, {int startIndex = 0}) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      final useCase = ref.read(playSmartMixUseCaseProvider);
      final items = await useCase.execute(songs: songs, playIndex: startIndex);
      if (_operationVersion != v) return;
      await _handler.playNow(items, initialIndex: startIndex);
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          isSwitching: false,
          hasError: true,
          errorMessage: 'Failed to play smart mix: $e',
        );
      }
    }
  }

  Future<void> playNext(MediaItem item) async {
    await _handler.playNext(item);
  }

  Future<void> playNextVideoId(
    String videoId, {
    required String title,
    required String artist,
    String? thumbnailUrl,
    int? durationSec,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    bool isExplicit = false,
  }) async {
    final useCase = ref.read(playVideoIdUseCaseProvider);
    try {
      final streamUrl = await useCase.resolveStreamUrl(videoId);
      final extras = <String, dynamic>{
        'url': streamUrl,
        'videoId': videoId,
        'isVideo': isVideo,
        'isExplicit': isExplicit,
      };
      if (artistId != null) extras['artistId'] = artistId;
      if (albumId != null) extras['albumId'] = albumId;
      final item = MediaItem(
        id: videoId,
        title: title,
        artist: artist,
        album: albumName,
        duration: Duration(seconds: durationSec ?? 0),
        artUri: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
        extras: extras,
      );
      await playNext(item);
    } catch (e) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Failed to add to queue: $e',
      );
    }
  }

  Future<void> addToQueue(MediaItem item) async {
    await _handler.addToQueue(item);
  }

  Future<void> addToQueueVideoId(
    String videoId, {
    required String title,
    required String artist,
    String? thumbnailUrl,
    int? durationSec,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    bool isExplicit = false,
  }) async {
    final useCase = ref.read(playVideoIdUseCaseProvider);
    try {
      final streamUrl = await useCase.resolveStreamUrl(videoId);
      final extras = <String, dynamic>{
        'url': streamUrl,
        'videoId': videoId,
        'isVideo': isVideo,
        'isExplicit': isExplicit,
      };
      if (artistId != null) extras['artistId'] = artistId;
      if (albumId != null) extras['albumId'] = albumId;
      final item = MediaItem(
        id: videoId,
        title: title,
        artist: artist,
        album: albumName,
        duration: Duration(seconds: durationSec ?? 0),
        artUri: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
        extras: extras,
      );
      await addToQueue(item);
    } catch (e) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Failed to add to queue: $e',
      );
    }
  }

  Future<void> addAllToQueue(List<MediaItem> items) async {
    await _handler.addAllToQueue(items);
  }

  Future<void> removeAt(int index) async {
    await _handler.removeQueueItemAt(index);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    _isReordering = true;
    // Optimistic UI update
    final items = List<MediaItem>.from(state.queue);
    if (newIndex >= 0 && newIndex < items.length) {
      final moved = items.removeAt(oldIndex);
      items.insert(newIndex, moved);
      state = state.copyWith(queue: items);
    }

    try {
      await _handler.moveQueueItem(oldIndex, newIndex);
      await _handler.persistQueue(state.queue);
    } finally {
      _isReordering = false;
      // Manually sync with the handler's final queue state to ensure correctness.
      final actualQueue = _handler.queue.value;
      final currentQueue = state.queue;
      final queueChanged =
          currentQueue.length != actualQueue.length ||
          !const ListEquality().equals(
            currentQueue
                .map((e) => e.extras?['queueId'] as String? ?? e.id)
                .toList(),
            actualQueue
                .map((e) => e.extras?['queueId'] as String? ?? e.id)
                .toList(),
          );
      if (queueChanged) {
        state = state.copyWith(queue: actualQueue);
      }
    }
  }

  Future<void> clearQueue() async {
    await _handler.clearQueue();
    await ref.read(queueUseCaseProvider).clearQueue();
  }

  // ── Metodi base ───────────────────────────────────────────────

  Future<void> play() => _handler.play();

  Future<void> pause() => _handler.pause();

  Future<void> togglePlayPause() async {
    if (state.isBlocked) return;
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> seek(Duration position) {
    if (state.isBlocked) return Future.value();
    return _handler.seek(position);
  }

  Future<void> skipToNext() {
    if (state.isBlocked) return Future.value();
    return _handler.skipToNext();
  }

  Future<void> skipToPrevious() {
    if (state.isBlocked) return Future.value();
    return _handler.skipToPrevious();
  }

  Future<void> skipToIndex(int index) async {
    if (state.isBlocked) return;
    final v = ++_operationVersion;
    // Pause immediately so the user hears a clean cut instead of the current
    // song continuing while the target URL is resolved.
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      await _handler.skipToQueueItem(index);
      if (_operationVersion != v) return;
      await _handler.play();
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          isSwitching: false,
          hasError: true,
          errorMessage: 'Failed to skip to song: $e',
        );
      }
    }
  }

  Future<void> playSong(MediaItem song) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      await _handler.setQueue([song]);
      if (_operationVersion != v) return;
      await _handler.play();
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          isSwitching: false,
          hasError: true,
          errorMessage: 'Failed to play song: $e',
        );
      }
    }
  }

  Future<void> playQueue(List<MediaItem> songs, {int initialIndex = 0}) async {
    ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      await _handler.playNow(songs, initialIndex: initialIndex);
    } catch (e) {
      state = state.copyWith(
        isSwitching: false,
        hasError: true,
        errorMessage: 'Failed to start playback: $e',
      );
    }
  }

  Future<void> playVideoId(
    String videoId, {
    bool? isVideo,
    bool? isExplicit,
  }) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      final item = await ref
          .read(playVideoIdUseCaseProvider)
          .execute(videoId, isVideoHint: isVideo, isExplicitHint: isExplicit);
      if (_operationVersion != v) return;
      await _handler.setQueue([item]);
      if (_operationVersion != v) return;
      await _handler.play();
    } catch (e) {
      if (_operationVersion == v) {
        state = state.copyWith(
          hasError: true,
          errorMessage: 'Failed to play video: $e',
          isSwitching: false,
        );
      }
    }
  }

  Future<void> setShuffleMode(AudioServiceShuffleMode mode) =>
      _handler.setShuffleMode(mode);

  Future<void> toggleShuffle() async {
    final newMode =
        state.shuffleMode == AudioServiceShuffleMode.none
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none;
    await _handler.setShuffleMode(newMode);
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      _handler.setRepeatMode(mode);

  Future<void> cycleRepeatMode() async {
    const modes = [
      AudioServiceRepeatMode.none,
      AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.one,
    ];
    final idx = modes.indexOf(state.repeatMode);
    final next = modes[(idx + 1) % modes.length];
    await _handler.setRepeatMode(next);
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerTick?.cancel();
    _sleepTimerDuration = duration;
    _sleepTimerStart = DateTime.now();
    _sleepTimer = Timer(duration, () {
      _handler.pause();
      _sleepTimer = null;
      _sleepTimerDuration = null;
      _sleepTimerStart = null;
      _sleepTimerTick?.cancel();
      _sleepTimerTick = null;
      state = state.copyWith(clearSleepTimer: true);
    });
    _sleepTimerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepTimerStart == null || _sleepTimerDuration == null) {
        _sleepTimerTick?.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_sleepTimerStart!);
      final remaining = _sleepTimerDuration! - elapsed;
      if (remaining <= Duration.zero) {
        _sleepTimerTick?.cancel();
        return;
      }
      state = state.copyWith(sleepTimerRemaining: remaining);
    });
    state = state.copyWith(sleepTimerRemaining: duration);
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerTick?.cancel();
    _sleepTimer = null;
    _sleepTimerDuration = null;
    _sleepTimerStart = null;
    _sleepTimerTick = null;
    state = state.copyWith(clearSleepTimer: true);
  }

  Duration? get sleepTimerRemaining {
    if (_sleepTimerStart == null || _sleepTimerDuration == null) return null;
    final elapsed = DateTime.now().difference(_sleepTimerStart!);
    final remaining = _sleepTimerDuration! - elapsed;
    return remaining > Duration.zero ? remaining : null;
  }
}
