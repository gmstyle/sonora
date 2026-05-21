import 'dart:io';

import 'package:audio_service/audio_service.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import '../../repositories/queue_repository.dart';

/// Restores the persisted queue from [QueueRepository] and ensures the first
/// item has a valid stream URL, re-resolving it if missing, expired, or
/// pointing to a deleted local file.
class QueueUseCase {
  final MusicRepository _musicRepository;
  final QueueRepository _queueRepository;
  final LibraryRepository? _libraryRepository;

  QueueUseCase(
    this._musicRepository,
    this._queueRepository, [
    this._libraryRepository,
  ]);

  Future<List<MediaItem>> execute() async {
    var items = await _queueRepository.restoreQueue();
    if (items.isEmpty) return [];

    final firstUrl = items[0].extras?['url'] as String?;
    if (firstUrl == null || firstUrl.isEmpty || _isUrlStale(firstUrl)) {
      if (firstUrl != null && firstUrl.startsWith('file://')) {
        _cleanupMissingDownload(firstUrl, items[0].id);
      }
      try {
        final url = await _musicRepository.getStreamUrl(items[0].id);
        items[0] = items[0].copyWith(extras: {...?items[0].extras, 'url': url});
      } catch (_) {}
    }

    return items;
  }

  bool _isUrlStale(String url) {
    if (url.startsWith('file://')) {
      final file = File.fromUri(Uri.parse(url));
      return !file.existsSync();
    }
    final expireParam = Uri.tryParse(url)?.queryParameters['expire'];
    if (expireParam == null) return true;
    final expireTs = int.tryParse(expireParam);
    if (expireTs == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireTs;
  }

  Future<void> _cleanupMissingDownload(String fileUrl, String videoId) async {
    if (_libraryRepository == null) return;
    final file = File.fromUri(Uri.parse(fileUrl));
    if (!file.existsSync()) {
      await _libraryRepository.deleteDownload(videoId);
    }
  }

  Future<void> persistQueue(List<MediaItem> queue) async {
    await _queueRepository.persistQueue(queue);
  }

  Future<void> clearQueue() async {
    await _queueRepository.clearQueue();
  }
}
