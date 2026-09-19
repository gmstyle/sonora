import 'package:path/path.dart' as p;

import '../models/download_group.dart';
import '../models/library_models.dart';

/// Known collection type prefixes used in bulk `batchId` values (`album:…`).
const kDownloadCollectionTypes = {
  'album',
  'playlist',
  'podcast',
  'localPlaylist',
};

/// Parses `album:id` / `playlist:id` / … into id + type.
({String collectionId, String collectionType})? parseDownloadBatchId(
  String? batchId,
) {
  if (batchId == null || batchId.isEmpty) return null;
  final idx = batchId.indexOf(':');
  if (idx <= 0 || idx >= batchId.length - 1) return null;
  final type = batchId.substring(0, idx);
  final id = batchId.substring(idx + 1);
  if (!kDownloadCollectionTypes.contains(type) || id.isEmpty) return null;
  return (collectionId: id, collectionType: type);
}

DownloadGroupKind? downloadGroupKindFromType(String? type) {
  return switch (type) {
    'album' => DownloadGroupKind.album,
    'playlist' => DownloadGroupKind.playlist,
    'podcast' => DownloadGroupKind.podcast,
    'localPlaylist' => DownloadGroupKind.localPlaylist,
    'inferred' => DownloadGroupKind.inferred,
    _ => null,
  };
}

/// Groups completed downloads: persisted collection > inferred folder > Singles.
List<DownloadGroup> groupCompletedDownloads(List<DownloadModel> downloads) {
  if (downloads.isEmpty) return const [];

  final rootParents = _shallowestParents(downloads);
  final buckets = <String, _MutableGroup>{};

  for (final d in downloads) {
    final assigned = _primaryAssignment(d, rootParents);
    final bucket = buckets.putIfAbsent(
      assigned.key,
      () => _MutableGroup(
        key: assigned.key,
        kind: assigned.kind,
        name: assigned.name,
      ),
    );
    bucket.tracks.add(d);
    if (bucket.name.isEmpty && assigned.name.isNotEmpty) {
      bucket.name = assigned.name;
    }
  }

  final groups =
      buckets.values
          .map(
            (b) => DownloadGroup(
              key: b.key,
              kind: b.kind,
              name: b.name,
              tracks: List<DownloadModel>.unmodifiable(b.tracks),
            ),
          )
          .toList();

  groups.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return groups;
}

({String key, DownloadGroupKind kind, String name}) _primaryAssignment(
  DownloadModel d,
  Set<String> rootParents,
) {
  final id = d.collectionId;
  final type = d.collectionType;
  final kind = downloadGroupKindFromType(type);
  if (id != null &&
      id.isNotEmpty &&
      kind != null &&
      kind != DownloadGroupKind.inferred) {
    return (
      key: '$type:$id',
      kind: kind,
      name: (d.collectionName?.isNotEmpty ?? false) ? d.collectionName! : id,
    );
  }

  final folder = _inferredFolderName(d.localPath, rootParents);
  if (folder != null) {
    return (
      key: 'inferred:$folder',
      kind: DownloadGroupKind.inferred,
      name: folder,
    );
  }

  return (key: 'singles', kind: DownloadGroupKind.singles, name: 'Singles');
}

/// Folder name when file lives in `…/Sonora/<name>/` or under a shallower root.
String? _inferredFolderName(String? localPath, Set<String> rootParents) {
  if (localPath == null || localPath.isEmpty) return null;
  final parent = p.normalize(p.dirname(localPath));
  final parentName = p.basename(parent);
  if (parentName.isEmpty || parentName == 'Sonora') return null;

  final grandparent = p.normalize(p.dirname(parent));
  if (p.basename(grandparent) == 'Sonora') return parentName;

  if (rootParents.contains(parent)) return null;
  for (final root in rootParents) {
    if (p.equals(grandparent, root)) return parentName;
  }
  return null;
}

Set<String> _shallowestParents(List<DownloadModel> downloads) {
  final parents =
      downloads
          .map((d) => d.localPath)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .map((path) => p.normalize(p.dirname(path)))
          .toSet();
  if (parents.isEmpty) return const {};

  int depth(String path) =>
      path.split(p.separator).where((s) => s.isNotEmpty).length;

  final minDepth = parents.map(depth).reduce((a, b) => a < b ? a : b);
  return parents.where((path) => depth(path) == minDepth).toSet();
}

class _MutableGroup {
  final String key;
  final DownloadGroupKind kind;
  String name;
  final List<DownloadModel> tracks = [];

  _MutableGroup({required this.key, required this.kind, required this.name});
}
