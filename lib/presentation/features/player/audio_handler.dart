import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;

  SonoraAudioHandler() {
    _setupListeners();
  }

  Stream<Duration?> get durationStream => _player.durationStream;

  void _setupListeners() {
    _player.playerStateStream.listen(_onPlayerStateChanged);
    _player.positionStream.listen(_onPositionChanged);
    _player.bufferedPositionStream.listen(_onBufferedPositionChanged);
    _player.currentIndexStream.listen(_onCurrentIndexChanged);
    _player.sequenceStateStream.listen(_onSequenceStateChanged);
  }

  void _onPlayerStateChanged(PlayerState state) {
    final processing = switch (state.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(
      playbackState.value.copyWith(
        processingState: processing,
        playing: state.playing,
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
      ),
    );
  }

  void _onPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    _handleCrossfade(position);
  }

  void _onBufferedPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(bufferedPosition: position));
  }

  void _onCurrentIndexChanged(int? index) {
    if (index == null) return;
    playbackState.add(playbackState.value.copyWith(queueIndex: index));
  }

  void _onSequenceStateChanged(SequenceState? sequenceState) {
    if (sequenceState == null) return;
    final source = sequenceState.currentSource;
    if (source != null) {
      mediaItem.add(source.tag as MediaItem);
    }
    final items =
        sequenceState.effectiveSequence.map((e) => e.tag as MediaItem).toList();
    queue.add(items);

    if (_crossfadeDuration > Duration.zero && _player.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyVolume(1.0);
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      _player.setVolume(v);
    }
  }

  void _handleCrossfade(Duration position) {
    if (_crossfadeDuration == Duration.zero) return;
    final duration = _player.duration;
    if (duration == null || !_player.playing) return;

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
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => LoopMode.all,
    };
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  List<MediaItem> get _currentQueue =>
      _player.sequence.map((e) => e.tag as MediaItem).toList();

  Future<void> setQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    queue.add(items);
    final audioSources =
        items.map((item) {
          final url = item.extras?['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return AudioSource.uri(Uri.parse(url), tag: item);
          }
          // Fallback to a silent audio source if no URL is provided, to ensure the queue can be set without errors.
          // TODO(Fase 5/7): questo caso non dovrebbe mai verificarsi a regime.
          // Ogni MediaItem deve essere inserito in coda solo DOPO che
          // StreamDatasource.getStreamUrl(videoId) ha risolto l'URL, oppure
          // l'handler deve risolvere l'URL on-demand in _onCurrentIndexChanged
          // prima di avviare play(). Rimuovere questo fallback una volta che
          // il lazy-loading di Fase 5 (playlist YT) e Fase 7 (playlist locale)
          // è implementato correttamente.
          return AudioSource.uri(
            Uri.parse(
              'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=',
            ),
            tag: item,
          );
        }).toList();
    await _player.setAudioSources(audioSources, initialIndex: initialIndex);
  }

  Future<void> playNow(List<MediaItem> items, {int initialIndex = 0}) async {
    await setQueue(items, initialIndex: initialIndex);
    await _player.play();
  }

  Future<void> playNext(MediaItem item) async {
    final current = _currentQueue;
    final ci = _player.currentIndex ?? 0;
    final insertAt = (ci + 1).clamp(0, current.length);
    final updated = [...current];
    updated.insert(insertAt, item);
    await setQueue(updated, initialIndex: ci);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final current = _currentQueue;
    await setQueue([
      ...current,
      mediaItem,
    ], initialIndex: _player.currentIndex ?? 0);
  }

  Future<void> addToQueue(MediaItem item) async {
    await addQueueItem(item);
  }

  Future<void> addAllToQueue(List<MediaItem> items) async {
    final current = _currentQueue;
    await setQueue([
      ...current,
      ...items,
    ], initialIndex: _player.currentIndex ?? 0);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final current = _currentQueue;
    if (index < 0 || index >= current.length) return;
    final updated = [...current]..removeAt(index);
    final ci = _player.currentIndex ?? 0;
    await setQueue(updated, initialIndex: ci < updated.length ? ci : 0);
  }

  Future<void> clearQueue() async {
    await _player.stop();
    await _player.setAudioSources([]);
    queue.add([]);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final current = _currentQueue;
    if (oldIndex < 0 || oldIndex >= current.length) return;
    if (newIndex < 0 || newIndex >= current.length) return;
    final updated = [...current];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    await setQueue(updated, initialIndex: _player.currentIndex ?? 0);
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    await super.onTaskRemoved();
  }

  void dispose() {
    _player.dispose();
  }
}
