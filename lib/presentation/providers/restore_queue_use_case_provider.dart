import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/restore_queue_use_case.dart';
import 'music_repository_provider.dart';
import 'queue_repository_provider.dart';

final restoreQueueUseCaseProvider = Provider<RestoreQueueUseCase>((ref) {
  return RestoreQueueUseCase(
    ref.watch(musicRepositoryProvider),
    ref.watch(queueRepositoryProvider),
  );
});
