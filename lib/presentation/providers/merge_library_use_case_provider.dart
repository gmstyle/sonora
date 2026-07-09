import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/backup/merge_library_use_case.dart';
import 'library_repository_provider.dart';

final mergeLibraryUseCaseProvider = Provider<MergeLibraryUseCase>((ref) {
  return MergeLibraryUseCase(ref.watch(libraryRepositoryProvider));
});
