import 'library_models.dart';

/// How a completed-download group was formed.
enum DownloadGroupKind {
  album,
  playlist,
  podcast,
  localPlaylist,
  inferred,
  singles,
}

/// One UI group of completed downloads (album, playlist, folder, or Singles).
class DownloadGroup {
  /// Stable key for selection / expand state (`album:id`, `inferred:Name`, `singles`).
  final String key;
  final DownloadGroupKind kind;
  final String name;
  final List<DownloadModel> tracks;

  const DownloadGroup({
    required this.key,
    required this.kind,
    required this.name,
    required this.tracks,
  });

  int get totalBytes =>
      tracks.fold<int>(0, (sum, t) => sum + (t.fileSize ?? 0));

  String? get thumbnailUrl {
    for (final t in tracks) {
      if (t.thumbnailUrl != null && t.thumbnailUrl!.isNotEmpty) {
        return t.thumbnailUrl;
      }
    }
    return null;
  }

  bool get isCollection => kind != DownloadGroupKind.singles;
}
