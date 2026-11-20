import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/download_group.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/presentation/features/downloads/widgets/completed_downloads_view.dart';
import 'package:sonora/presentation/providers/download_provider.dart';

DownloadModel _dl({
  required String videoId,
  required String title,
  int? collectionIndex,
  DateTime? downloadedAt,
  int? fileSize,
}) {
  return DownloadModel(
    videoId: videoId,
    title: title,
    artist: 'Artist',
    status: 'completed',
    collectionIndex: collectionIndex,
    downloadedAt: downloadedAt,
    fileSize: fileSize,
  );
}

void main() {
  group('sortDownloadTracks', () {
    test('newest uses collectionIndex ascending when present', () {
      final tracks = [
        _dl(videoId: 'c', title: 'C', collectionIndex: 2),
        _dl(videoId: 'a', title: 'A', collectionIndex: 0),
        _dl(videoId: 'b', title: 'B', collectionIndex: 1),
      ];
      final sorted = sortDownloadTracks(tracks, DownloadsSort.newest);
      expect(sorted.map((t) => t.videoId).toList(), ['a', 'b', 'c']);
    });

    test('newest falls back to downloadedAt desc for legacy rows', () {
      final tracks = [
        _dl(videoId: 'old', title: 'Old', downloadedAt: DateTime(2024, 1, 1)),
        _dl(videoId: 'new', title: 'New', downloadedAt: DateTime(2024, 6, 1)),
      ];
      final sorted = sortDownloadTracks(tracks, DownloadsSort.newest);
      expect(sorted.map((t) => t.videoId).toList(), ['new', 'old']);
    });

    test('newest prefers indexed tracks over legacy-only rows', () {
      final tracks = [
        _dl(
          videoId: 'legacy',
          title: 'Legacy',
          downloadedAt: DateTime(2025, 1, 1),
        ),
        _dl(videoId: 'indexed', title: 'Indexed', collectionIndex: 0),
      ];
      final sorted = sortDownloadTracks(tracks, DownloadsSort.newest);
      expect(sorted.map((t) => t.videoId).toList(), ['indexed', 'legacy']);
    });

    test('title and largest still override', () {
      final tracks = [
        _dl(videoId: 'b', title: 'Beta', collectionIndex: 0, fileSize: 10),
        _dl(videoId: 'a', title: 'Alpha', collectionIndex: 1, fileSize: 100),
      ];
      expect(
        sortDownloadTracks(tracks, DownloadsSort.title).map((t) => t.videoId),
        ['a', 'b'],
      );
      expect(
        sortDownloadTracks(tracks, DownloadsSort.largest).map((t) => t.videoId),
        ['a', 'b'],
      );
    });
  });

  group('sortDownloadGroups', () {
    final groups = [
      DownloadGroup(
        key: 'album:b',
        kind: DownloadGroupKind.album,
        name: 'Beta',
        tracks: [
          _dl(
            videoId: 'b1',
            title: 'B1',
            downloadedAt: DateTime(2024, 5, 1),
            fileSize: 50,
          ),
        ],
      ),
      DownloadGroup(
        key: 'album:a',
        kind: DownloadGroupKind.album,
        name: 'Alpha',
        tracks: [
          _dl(
            videoId: 'a1',
            title: 'A1',
            downloadedAt: DateTime(2024, 1, 1),
            fileSize: 200,
          ),
        ],
      ),
      DownloadGroup(
        key: 'album:c',
        kind: DownloadGroupKind.album,
        name: 'Gamma',
        tracks: [
          _dl(
            videoId: 'c1',
            title: 'C1',
            downloadedAt: DateTime(2024, 6, 1),
            fileSize: 100,
          ),
        ],
      ),
    ];

    test('newest sorts by latest track downloadedAt descending', () {
      expect(
        sortDownloadGroups(groups, DownloadsSort.newest).map((g) => g.key),
        ['album:c', 'album:b', 'album:a'],
      );
    });

    test('title sorts alphabetically', () {
      expect(
        sortDownloadGroups(groups, DownloadsSort.title).map((g) => g.key),
        ['album:a', 'album:b', 'album:c'],
      );
    });

    test('largest sorts by totalBytes descending', () {
      expect(
        sortDownloadGroups(groups, DownloadsSort.largest).map((g) => g.key),
        ['album:a', 'album:c', 'album:b'],
      );
    });
  });
}
