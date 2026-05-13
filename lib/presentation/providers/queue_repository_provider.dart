import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/queue_repository_impl.dart';
import '../../domain/repositories/queue_repository.dart';
import 'database_provider.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepositoryImpl(ref.watch(databaseProvider));
});
