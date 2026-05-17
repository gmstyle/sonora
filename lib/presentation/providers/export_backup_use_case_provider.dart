import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/backup/export_backup_use_case.dart';
import 'library_repository_provider.dart';

final exportBackupUseCaseProvider = Provider<ExportBackupUseCase>((ref) {
  return ExportBackupUseCase(ref.watch(libraryRepositoryProvider));
});
