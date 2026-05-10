import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/audio_handler.dart';
import 'settings_provider.dart';

final audioHandlerProvider = Provider<SonoraAudioHandler>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

final playerStateProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

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
          clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
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
        isLoading: s.processingState == AudioProcessingState.loading ||
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

  void play() => _handler.play();

  void pause() => _handler.pause();

  void togglePlayPause() {
    if (state.isPlaying) {
      _handler.pause();
    } else {
      _handler.play();
    }
  }

  void seek(Duration position) => _handler.seek(position);

  void skipToNext() => _handler.skipToNext();

  void skipToPrevious() => _handler.skipToPrevious();

  void playSong(MediaItem song) {
    _handler.setQueue([song]);
    _handler.play();
  }

  void playQueue(List<MediaItem> songs, {int initialIndex = 0}) {
    _handler.setQueue(songs, initialIndex: initialIndex);
    _handler.play();
  }

  void setShuffleMode(AudioServiceShuffleMode mode) {
    _handler.setShuffleMode(mode);
  }

  void toggleShuffle() {
    final newMode = state.shuffleMode == AudioServiceShuffleMode.none
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    _handler.setShuffleMode(newMode);
  }

  void setRepeatMode(AudioServiceRepeatMode mode) {
    _handler.setRepeatMode(mode);
  }

  void cycleRepeatMode() {
    const modes = [
      AudioServiceRepeatMode.none,
      AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.one,
    ];
    final idx = modes.indexOf(state.repeatMode);
    final next = modes[(idx + 1) % modes.length];
    _handler.setRepeatMode(next);
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
