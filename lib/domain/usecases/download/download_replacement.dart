import 'dart:io';

import '../../models/library_models.dart';
import '../../repositories/library_repository.dart';

/// Staging path used while a replacement download is in progress.
String downloadPartPath(String filePath) => '$filePath.part';

/// Snapshot of a completed download that must survive a failed replacement.
///
/// The previous on-disk file is deleted only after the new file is fully
/// written. If the replacement fails, the completed library row is restored.
class DownloadReplacement {
  const DownloadReplacement(this.previous);

  final DownloadModel? previous;

  /// Keeps a completed row so a failed re-download can restore it.
  factory DownloadReplacement.capture(DownloadModel? existing) {
    if (existing == null || existing.status != 'completed') {
      return const DownloadReplacement(null);
    }
    return DownloadReplacement(existing);
  }

  String? get oldPath {
    final path = previous?.localPath;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  Future<void> revertOnFailure({
    required LibraryRepository library,
    required String videoId,
    required String newFilePath,
  }) async {
    await _deleteIfExists(newFilePath);
    await _deleteIfExists(downloadPartPath(newFilePath));

    final retained = previous;
    if (retained == null) {
      try {
        await library.deleteDownload(videoId);
      } catch (_) {}
      return;
    }

    try {
      await library.insertDownload(
        videoId: retained.videoId,
        title: retained.title,
        artist: retained.artist,
        artistsJson: retained.artistsJson,
        thumbnailUrl: retained.thumbnailUrl,
        status: retained.status,
        localPath: retained.localPath,
        format: retained.format,
        fileSize: retained.fileSize,
        downloadedAt: retained.downloadedAt,
        isVideo: retained.isVideo,
        isExplicit: retained.isExplicit,
        collectionId: retained.collectionId,
        collectionType: retained.collectionType,
        collectionName: retained.collectionName,
      );
    } catch (_) {}
  }

  /// Renames the staging file into place, then removes the previous path
  /// when it changed (e.g. single absorbed into an album folder).
  Future<void> promoteOnSuccess(String newFilePath) async {
    await _replaceWithPart(newFilePath);
    final old = oldPath;
    if (old != null && old != newFilePath) {
      await _deleteIfExists(old);
    }
  }
}

Future<void> _replaceWithPart(String filePath) async {
  final part = File(downloadPartPath(filePath));
  if (!await part.exists()) return;
  try {
    await part.rename(filePath);
  } on FileSystemException {
    await part.copy(filePath);
    await part.delete();
  }
}

Future<void> _deleteIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
