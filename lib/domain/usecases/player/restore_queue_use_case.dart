import 'package:audio_service/audio_service.dart';
import '../../repositories/music_repository.dart';
import '../../repositories/queue_repository.dart';

/// Restores the persisted queue from [QueueRepository] and ensures the first
/// item has a resolved stream URL (fetched from [MusicRepository] if missing).
class RestoreQueueUseCase {
  final MusicRepository _musicRepository;
  final QueueRepository _queueRepository;

  RestoreQueueUseCase(this._musicRepository, this._queueRepository);

  Future<List<MediaItem>> execute() async {
    var items = await _queueRepository.restoreQueue();
    if (items.isEmpty) return [];

    final firstUrl = items[0].extras?['url'] as String?;
    if (firstUrl == null || firstUrl.isEmpty) {
      try {
        final url = await _musicRepository.getStreamUrl(items[0].id);
        items[0] = items[0].copyWith(extras: {...?items[0].extras, 'url': url});
      } catch (_) {}
    }

    return items;
  }
}
