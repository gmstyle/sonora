import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/queue_use_case.dart';
import 'queue_repository_provider.dart';

final queueUseCaseProvider = Provider<QueueUseCase>((ref) {
  return QueueUseCase(ref.watch(queueRepositoryProvider));
});
