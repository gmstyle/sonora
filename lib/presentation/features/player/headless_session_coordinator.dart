import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';
import '../../providers/settings_provider.dart';

/// Owns background-safe listening history recording and Up Next autoplay
/// prefetch/advance so Android Auto works identically even when the Flutter UI
/// (`PlayerNotifier`) has never been mounted.
class HeadlessSessionCoordinator {
  final LibraryRepository _libraryRepo;
  final StartRadioUseCase _startRadioUseCase;
  final SharedPreferences _prefs;
  final bool Function() _isRestoring;
  final bool Function() _isOffline;
  final List<MediaItem> Function() _getQueue;
  final int Function() _getCurrentIndex;
  final int? Function() _getUpNextStartIndex;
  final AudioServiceRepeatMode Function() _getRepeatMode;
  final Future<void> Function(List<MediaItem> items) _appendUpNext;
  final Future<void> Function(int index) _skipToQueueItem;
  final Future<void> Function() _play;

  String? _lastRecordedVideoId;
  bool _isFetchingUpNext = false;
  int _sessionGeneration = 0;

  HeadlessSessionCoordinator({
    required this._libraryRepo,
    required this._startRadioUseCase,
    required this._prefs,
    required this._isRestoring,
    required this._isOffline,
    required this._getQueue,
    required this._getCurrentIndex,
    required this._getUpNextStartIndex,
    required this._getRepeatMode,
    required this._appendUpNext,
    required this._skipToQueueItem,
    required this._play,
  });

  bool get isFetchingUpNext => _isFetchingUpNext;

  /// Invalidates any in-flight autoplay fetch and allows re-recording the next
  /// explicit track play even if it shares the previous videoId.
  void resetSession() {
    _sessionGeneration++;
    _lastRecordedVideoId = null;
  }

  Future<void> onTrackChanged(MediaItem item) async {
    if (_isRestoring()) return;
    if (!(_prefs.getBool(kTrackHistoryKey) ?? true)) return;

    final track = QueueTrack.fromMediaItem(item);
    if (track.videoId.isEmpty || track.videoId == _lastRecordedVideoId) return;
    _lastRecordedVideoId = track.videoId;

    try {
      await _libraryRepo.recordPlay(
        track.videoId,
        track.title,
        track.artist ?? 'Unknown Artist',
        thumbnailUrl: track.artUri?.toString(),
        duration: track.duration?.inSeconds,
        isVideo: track.isVideo,
        isExplicit: track.isExplicit,
        contentType: track.contentType,
        podcastBrowseId: track.podcastBrowseId,
      );
    } catch (_) {}
  }

  bool _canAutoPlayItem(MediaItem? item) {
    if (item == null) return false;
    if (!(_prefs.getBool(kAutoPlayUpNextKey) ?? true)) return false;
    if (_isOffline()) return false;
    if (_getRepeatMode() != AudioServiceRepeatMode.none) return false;
    if (_isRestoring()) return false;
    if (QueueTrack.fromMediaItem(item).isEpisode) return false;
    return true;
  }

  Future<void> maybePrefetchUpNext(MediaItem? currentItem) async {
    if (!_canAutoPlayItem(currentItem)) return;
    if (_isFetchingUpNext) return;

    final queue = _getQueue();
    final idx = _getCurrentIndex();
    if (queue.isEmpty || idx < queue.length - 1) return;

    final upNextStart = _getUpNextStartIndex();
    if (upNextStart != null && upNextStart > idx) return;

    final seedId = currentItem!.id;
    if (seedId.isEmpty) return;

    _isFetchingUpNext = true;
    final gen = _sessionGeneration;
    try {
      final result = await _startRadioUseCase.execute(
        seedId,
        resolveFirstUrl: false,
      );
      if (gen != _sessionGeneration) return;
      await _appendUpNext([result.firstItem]);
      if (gen != _sessionGeneration) return;
      if (result.remaining.isNotEmpty) {
        final pending = _startRadioUseCase.toPendingItems(result.remaining);
        if (gen != _sessionGeneration) return;
        await _appendUpNext(pending);
      }
    } catch (_) {
    } finally {
      _isFetchingUpNext = false;
    }
  }

  Future<void> fetchUpNextAndAdvance(MediaItem? currentItem) async {
    if (!_canAutoPlayItem(currentItem)) return;
    if (_isFetchingUpNext) return;

    final queue = _getQueue();
    final idx = _getCurrentIndex();
    final upNextStart = _getUpNextStartIndex();
    if (upNextStart != null &&
        upNextStart > idx &&
        upNextStart < queue.length) {
      await _skipToQueueItem(upNextStart);
      await _play();
      return;
    }

    final seedId = currentItem!.id;
    if (seedId.isEmpty) return;

    _isFetchingUpNext = true;
    final gen = _sessionGeneration;
    try {
      final result = await _startRadioUseCase.execute(seedId);
      if (gen != _sessionGeneration) return;

      final insertIndex = _getQueue().length;
      await _appendUpNext([result.firstItem]);
      if (gen != _sessionGeneration) return;

      await _skipToQueueItem(insertIndex);
      if (gen != _sessionGeneration) return;
      await _play();

      if (result.remaining.isNotEmpty) {
        final pending = _startRadioUseCase.toPendingItems(result.remaining);
        if (gen != _sessionGeneration) return;
        await _appendUpNext(pending);
      }
    } catch (_) {
    } finally {
      _isFetchingUpNext = false;
    }
  }
}
