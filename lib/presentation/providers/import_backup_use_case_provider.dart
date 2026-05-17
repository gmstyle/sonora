import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/backup/import_backup_use_case.dart';
import 'library_repository_provider.dart';

final importBackupUseCaseProvider = Provider<ImportBackupUseCase>((ref) {
  return ImportBackupUseCase(ref.watch(libraryRepositoryProvider));
});
