import 'package:audio_service/audio_service.dart';
import '../../repositories/queue_repository.dart';

/// Handles queue persistence operations.
///
/// NOTE: queue restore is performed directly by [SonoraAudioHandler._initRestore],
/// which owns the full restore lifecycle (URL resolution, player open, seek).
/// This use-case is intentionally limited to persistence helpers only.
class QueueUseCase {
  final QueueRepository _queueRepository;

  QueueUseCase(this._queueRepository);

  Future<void> persistQueue(List<MediaItem> queue) async {
    await _queueRepository.persistQueue(queue);
  }

  Future<void> clearQueue() async {
    await _queueRepository.clearQueue();
  }
}
