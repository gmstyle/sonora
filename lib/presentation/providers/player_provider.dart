import 'dart:async';
import 'package:collection/collection.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/audio_handler.dart';
import 'library_notifier.dart';
import 'play_video_id_use_case_provider.dart';
import 'queue_use_case_provider.dart';
import 'settings_provider.dart';
import 'start_radio_use_case_provider.dart';

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

  PlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isSwitching,
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

class PlayerNotifier extends Notifier<PlayerState> {
  SonoraAudioHandler get _handler => ref.read(audioHandlerProvider);

  StreamSubscription? _playbackSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playErrorSub;
  bool _isFetchingUpNext = false;
  int _operationVersion = 0;
  Timer? _sleepTimer;
  Timer? _sleepTimerTick;
  DateTime? _sleepTimerStart;
  Duration? _sleepTimerDuration;
  bool _isReordering = false;

  @override
  PlayerState build() {
    // Subscribe to position separately so that frequent position ticks
    // do not flow through playbackState (which would cause Android Auto
    // to re-render the queue view and reset scroll on every tick).
    _positionSub = _handler.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _playbackSub = _handler.playbackState.listen((s) {
      final wasSwitching = state.isSwitching;
      state = state.copyWith(
        isPlaying: s.playing,
        isPaused: !s.playing && s.processingState == AudioProcessingState.ready,
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
        isSwitching:
            wasSwitching && s.processingState != AudioProcessingState.ready
                ? true
                : false,
      );

      if (s.processingState == AudioProcessingState.ready) {
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
        if (state.currentIndex >= state.queue.length - 1 &&
            !wasSwitching &&
            !_isFetchingUpNext &&
            ref.read(settingsProvider).autoPlayUpNext) {
          _isFetchingUpNext = true;
          _prefetchAutoPlayUpNext();
        }
      }

      if (s.processingState == AudioProcessingState.completed &&
          !_isFetchingUpNext &&
          state.queue.isNotEmpty &&
          state.currentIndex >= state.queue.length - 1 &&
          ref.read(settingsProvider).autoPlayUpNext) {
        _isFetchingUpNext = true;
        _fetchAutoPlayUpNext();
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
              isVideo: item.extras?['isVideo'] == true,
            );
      }
    });

    _queueSub = _handler.queue.listen((items) {
      if (_isReordering) return;
      final currentQueue = state.queue;
      final queueChanged =
          currentQueue.length != items.length ||
          !const ListEquality().equals(
            currentQueue.map((e) => e.id).toList(),
            items.map((e) => e.id).toList(),
          );
      if (queueChanged) {
        state = state.copyWith(queue: items);
      }

      // isSwitching is true during playSong/playVideoId/playQueue while the new
      // queue is being set up. Skipping here prevents a spurious prefetch when
      // state.currentIndex still holds the old (larger) index from the previous
      // queue and state.isPlaying hasn't been updated yet from the pending
      // pause() stream event.
      if (state.currentIndex >= items.length - 1 &&
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

    ref.onDispose(() {
      _playbackSub?.cancel();
      _mediaItemSub?.cancel();
      _queueSub?.cancel();
      _durationSub?.cancel();
      _positionSub?.cancel();
      _playErrorSub?.cancel();
      _sleepTimer?.cancel();
      _sleepTimerTick?.cancel();
    });

    _handler.setCrossfadeDuration(ref.read(settingsProvider).crossfadeDuration);
    ref.listen(settingsProvider, (prev, next) {
      if (prev?.crossfadeDuration != next.crossfadeDuration) {
        _handler.setCrossfadeDuration(next.crossfadeDuration);
      }
    });

    return const PlayerState();
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
    await _handler.playNow(items, initialIndex: initialIndex);
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
  }) async {
    final useCase = ref.read(playVideoIdUseCaseProvider);
    try {
      final streamUrl = await useCase.resolveStreamUrl(videoId);
      final extras = <String, dynamic>{
        'url': streamUrl,
        'videoId': videoId,
        'isVideo': isVideo,
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
  }) async {
    final useCase = ref.read(playVideoIdUseCaseProvider);
    try {
      final streamUrl = await useCase.resolveStreamUrl(videoId);
      final extras = <String, dynamic>{
        'url': streamUrl,
        'videoId': videoId,
        'isVideo': isVideo,
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
            currentQueue.map((e) => e.id).toList(),
            actualQueue.map((e) => e.id).toList(),
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
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> skipToNext() => _handler.skipToNext();

  Future<void> skipToPrevious() => _handler.skipToPrevious();

  Future<void> skipToIndex(int index) async {
    await _handler.skipToQueueItem(index);
    if (!state.isPlaying) await _handler.play();
  }

  Future<void> playSong(MediaItem song) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    await _handler.setQueue([song]);
    if (_operationVersion != v) return;
    await _handler.play();
  }

  Future<void> playQueue(List<MediaItem> songs, {int initialIndex = 0}) async {
    ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    await _handler.playNow(songs);
  }

  Future<void> playVideoId(String videoId, {bool? isVideo}) async {
    final v = ++_operationVersion;
    await _handler.pause();
    state = state.copyWith(isSwitching: true);
    try {
      final item = await ref
          .read(playVideoIdUseCaseProvider)
          .execute(videoId, isVideoHint: isVideo);
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
