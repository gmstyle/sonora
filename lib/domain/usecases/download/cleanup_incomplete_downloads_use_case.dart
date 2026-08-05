import 'dart:io';

import '../../repositories/library_repository.dart';

/// Removes download rows that never reached the `completed` status (e.g. the
/// app was killed mid-download) together with their partial files on disk.
class CleanupIncompleteDownloadsUseCase {
  final LibraryRepository _libraryRepository;

  CleanupIncompleteDownloadsUseCase(this._libraryRepository);

  Future<void> execute() async {
    final incomplete = await _libraryRepository.getIncompleteDownloads();
    if (incomplete.isEmpty) return;

    await _libraryRepository.deleteIncompleteDownloads();

    for (final download in incomplete) {
      final path = download.localPath;
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}
