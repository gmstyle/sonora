import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/download_group.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/utils/download_grouping.dart';

DownloadModel _dl({
  required String videoId,
  String title = 'Track',
  String? localPath,
  String? collectionId,
  String? collectionType,
  String? collectionName,
  int? fileSize,
}) {
  return DownloadModel(
    videoId: videoId,
    title: title,
    artist: 'Artist',
    status: 'completed',
    localPath: localPath,
    collectionId: collectionId,
    collectionType: collectionType,
    collectionName: collectionName,
    fileSize: fileSize,
    downloadedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('parseDownloadBatchId', () {
    test('parses known prefixes', () {
      expect(
        parseDownloadBatchId('album:MPREb_abc'),
        (collectionId: 'MPREb_abc', collectionType: 'album'),
      );
      expect(
        parseDownloadBatchId('localPlaylist:42'),
        (collectionId: '42', collectionType: 'localPlaylist'),
      );
    });

    test('rejects invalid values', () {
      expect(parseDownloadBatchId(null), isNull);
      expect(parseDownloadBatchId(''), isNull);
      expect(parseDownloadBatchId('album:'), isNull);
      expect(parseDownloadBatchId('unknown:id'), isNull);
    });
  });

  group('groupCompletedDownloads', () {
    test('puts root Sonora files in Singles', () {
      final groups = groupCompletedDownloads([
        _dl(
          videoId: 'a',
          localPath: '/storage/Downloads/Sonora/Song-a.m4a',
        ),
        _dl(
          videoId: 'b',
          localPath: '/storage/Downloads/Sonora/Song-b.m4a',
        ),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, DownloadGroupKind.singles);
      expect(groups.single.tracks, hasLength(2));
    });

    test('groups by collectionId as primary', () {
      final groups = groupCompletedDownloads([
        _dl(
          videoId: '1',
          collectionId: 'alb1',
          collectionType: 'album',
          collectionName: 'After Hours',
          localPath: '/storage/Downloads/Sonora/After Hours/1.m4a',
        ),
        _dl(
          videoId: '2',
          collectionId: 'alb1',
          collectionType: 'album',
          collectionName: 'After Hours',
          localPath: '/storage/Downloads/Sonora/After Hours/2.m4a',
        ),
        _dl(
          videoId: '3',
          collectionId: 'alb2',
          collectionType: 'album',
          collectionName: 'Dawn FM',
          localPath: '/storage/Downloads/Sonora/Dawn FM/3.m4a',
        ),
      ]);
      expect(groups, hasLength(2));
      expect(groups.map((g) => g.name), containsAll(['After Hours', 'Dawn FM']));
      expect(groups.every((g) => g.kind == DownloadGroupKind.album), isTrue);
    });

    test('absorption: same videoId lives only in collection group', () {
      // Simulates post-absorption DB state: former single now has collection meta.
      final groups = groupCompletedDownloads([
        _dl(
          videoId: 'shared',
          collectionId: 'alb1',
          collectionType: 'album',
          collectionName: 'After Hours',
          localPath: '/storage/Downloads/Sonora/After Hours/shared.m4a',
        ),
        _dl(
          videoId: 'solo',
          localPath: '/storage/Downloads/Sonora/solo.m4a',
        ),
      ]);
      expect(groups, hasLength(2));
      final album = groups.firstWhere((g) => g.kind == DownloadGroupKind.album);
      final singles = groups.firstWhere(
        (g) => g.kind == DownloadGroupKind.singles,
      );
      expect(album.tracks.map((t) => t.videoId), ['shared']);
      expect(singles.tracks.map((t) => t.videoId), ['solo']);
    });

    test('infers folder under Sonora without collection meta', () {
      final groups = groupCompletedDownloads([
        _dl(
          videoId: '1',
          localPath: '/storage/Downloads/Sonora/Late Night/1.m4a',
        ),
        _dl(
          videoId: '2',
          localPath: '/storage/Downloads/Sonora/Late Night/2.m4a',
        ),
        _dl(
          videoId: '3',
          localPath: '/storage/Downloads/Sonora/3.m4a',
        ),
      ]);
      expect(groups, hasLength(2));
      final inferred = groups.firstWhere(
        (g) => g.kind == DownloadGroupKind.inferred,
      );
      expect(inferred.name, 'Late Night');
      expect(inferred.tracks, hasLength(2));
      expect(
        groups.firstWhere((g) => g.kind == DownloadGroupKind.singles).tracks,
        hasLength(1),
      );
    });

    test('orders sections album before playlist before singles', () {
      final groups = groupCompletedDownloads([
        _dl(
          videoId: 's',
          localPath: '/storage/Downloads/Sonora/s.m4a',
        ),
        _dl(
          videoId: 'p',
          collectionId: 'pl1',
          collectionType: 'playlist',
          collectionName: 'Drive',
        ),
        _dl(
          videoId: 'a',
          collectionId: 'al1',
          collectionType: 'album',
          collectionName: 'Album',
        ),
      ]);
      expect(groups.map((g) => g.kind).toList(), [
        DownloadGroupKind.album,
        DownloadGroupKind.playlist,
        DownloadGroupKind.singles,
      ]);
    });
  });
}
