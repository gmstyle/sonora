import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/library_repository_provider.dart';

final homeSectionsProvider = FutureProvider((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getHomeSections();
});

final recentHistoryProvider = FutureProvider((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getRecentHistory(limit: 10);
});
