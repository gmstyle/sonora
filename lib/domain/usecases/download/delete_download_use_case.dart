import 'dart:io';

import '../../repositories/library_repository.dart';

class DeleteDownloadUseCase {
  final LibraryRepository _libraryRepository;

  DeleteDownloadUseCase(this._libraryRepository);

  Future<void> execute(String videoId) async {
    final download = await _libraryRepository.getDownload(videoId);
    await _libraryRepository.deleteDownload(videoId);

    final path = download?.localPath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}
