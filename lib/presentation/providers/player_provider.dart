import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/audio_handler.dart';
import 'music_repository_provider.dart';
import 'settings_provider.dart';

final audioHandlerProvider = Provider<SonoraAudioHandler>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final playerStateProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

class PlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isPaused;
  final bool hasError;
  final String? errorMessage;
  final MediaItem? currentSong;
  final List<MediaItem> queue;
  final Duration position;
  final Duration duration;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final Duration? sleepTimerRemaining;

  const PlayerState({
    this.isPlaying = false,
    this.isLoading = false,
    this.isPaused = false,
    this.hasError = false,
    this.errorMessage,
    this.currentSong,
    this.queue = const [],
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleMode = AudioServiceShuffleMode.none,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.sleepTimerRemaining,
  });

  PlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isPaused,
    bool? hasError,
    String? errorMessage,
    MediaItem? currentSong,
    List<MediaItem>? queue,
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
      isPaused: isPaused ?? this.isPaused,
      hasError: hasError ?? this.hasError,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
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
  Timer? _sleepTimer;
  Timer? _sleepTimerTick;
  DateTime? _sleepTimerStart;
  Duration? _sleepTimerDuration;

  @override
  PlayerState build() {
    _playbackSub = _handler.playbackState.listen((s) {
      state = state.copyWith(
        isPlaying: s.playing,
        isPaused: !s.playing && s.processingState == AudioProcessingState.ready,
        isLoading:
            s.processingState == AudioProcessingState.loading ||
            s.processingState == AudioProcessingState.buffering,
        hasError: s.processingState == AudioProcessingState.error,
        position: s.position,
        shuffleMode: s.shuffleMode,
        repeatMode: s.repeatMode,
      );
    });

    _mediaItemSub = _handler.mediaItem.listen((item) {
      state = state.copyWith(currentSong: item);
    });

    _queueSub = _handler.queue.listen((items) {
      state = state.copyWith(queue: items);
    });

    _durationSub = _handler.durationStream.listen((d) {
      state = state.copyWith(duration: d);
    });

    ref.onDispose(() {
      _playbackSub?.cancel();
      _mediaItemSub?.cancel();
      _queueSub?.cancel();
      _durationSub?.cancel();
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

  Future<void> playSong(MediaItem song) async {
    await _handler.setQueue([song]);
    await _handler.play();
  }

  Future<void> playQueue(List<MediaItem> songs, {int initialIndex = 0}) async {
    await _handler.setQueue(songs, initialIndex: initialIndex);
    await _handler.play();
  }

  Future<void> playVideoId(String videoId) async {
    final repo = ref.read(musicRepositoryProvider);
    try {
      String title, artistName, thumbnailUrl;
      int durationSec;
      bool isVideo;

      try {
        final song = await repo.getSong(videoId);
        title = song.name;
        artistName = song.artist.name;
        durationSec = song.duration;
        thumbnailUrl =
            song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '';
        isVideo = false;
      } catch (_) {
        final video = await repo.getVideo(videoId);
        title = video.name;
        artistName = video.artist.name;
        durationSec = video.duration;
        thumbnailUrl =
            video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
        isVideo = true;
      }

      final streamUrl = await repo.getStreamUrl(videoId);
      final item = MediaItem(
        id: videoId,
        title: title,
        artist: artistName,
        duration: Duration(seconds: durationSec),
        artUri: thumbnailUrl.isNotEmpty ? Uri.parse(thumbnailUrl) : null,
        extras: {'url': streamUrl, 'videoId': videoId, 'isVideo': isVideo},
      );
      await playSong(item);
    } catch (e) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Failed to play video: $e',
      );
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
