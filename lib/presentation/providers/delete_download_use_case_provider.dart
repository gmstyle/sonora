import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/download/delete_download_use_case.dart';
import 'library_repository_provider.dart';

final deleteDownloadUseCaseProvider = Provider<DeleteDownloadUseCase>((ref) {
  return DeleteDownloadUseCase(ref.watch(libraryRepositoryProvider));
});
