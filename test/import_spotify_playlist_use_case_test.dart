import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/playlist_link_parser.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/models/playlist_import.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/playlist/import_remote_playlist_use_case.dart';
import 'package:sonora/domain/usecases/playlist/import_spotify_playlist_use_case.dart';
import 'package:sonora/domain/usecases/playlist/refresh_linked_playlist_use_case.dart';
import 'package:sonora/domain/usecases/playlist/sync_youtube_playlist_use_case.dart';

void main() {
  late _FakeLibraryRepository library;

  setUp(() {
    library = _FakeLibraryRepository();
  });

  SongDetailed song({
    required String id,
    required String title,
    required String artist,
    int duration = 180,
    List<ArtistBasic>? artists,
  }) {
    return SongDetailed(
      type: 'SONG',
      videoId: id,
      name: title,
      artists: artists ?? [ArtistBasic(name: artist)],
      duration: duration,
      thumbnails: const [],
    );
  }

  group('parsePlaylistLinkFromDescription', () {
    test('parses YouTube sync descriptions', () {
      final parsed = parsePlaylistLinkFromDescription(
        'Synced from YouTube (ID: PLabc123)',
      );
      expect(parsed?.sourceKind, 'youtube');
      expect(parsed?.remoteId, 'PLabc123');
    });

    test('parses Spotify import descriptions', () {
      final parsed = parsePlaylistLinkFromDescription(
        'Imported from Spotify (ID: 5PlaEJOgemuwJGdHmCTAxg) — first 100 tracks',
      );
      expect(parsed?.sourceKind, 'spotify');
      expect(parsed?.remoteId, '5PlaEJOgemuwJGdHmCTAxg');
    });

    test('returns null for unrelated text', () {
      expect(parsePlaylistLinkFromDescription('My mixtape'), isNull);
    });
  });

  group('diffPlaylistEntries', () {
    PlaylistEntryModel entry(String id, int pos) =>
        PlaylistEntryModel(playlistId: 1, videoId: id, position: pos);

    test('detects adds and removes', () {
      final diff = diffPlaylistEntries(
        [entry('a', 0), entry('b', 1)],
        [entry('b', 0), entry('c', 1)],
      );
      expect(diff.added, 1);
      expect(diff.removed, 1);
      expect(diff.reordered, isFalse);
    });

    test('detects reorder without membership change', () {
      final diff = diffPlaylistEntries(
        [entry('a', 0), entry('b', 1)],
        [entry('b', 0), entry('a', 1)],
      );
      expect(diff.added, 0);
      expect(diff.removed, 0);
      expect(diff.reordered, isTrue);
    });
  });

  test('imports matched Spotify tracks into a local playlist', () async {
    const snapshot = SpotifyPlaylistSnapshot(
      id: '5PlaEJOgemuwJGdHmCTAxg',
      name: 'myLib',
      tracks: [
        SpotifyPlaylistTrack(
          title: 'Someone You Loved',
          subtitle: 'Lewis Capaldi',
          durationMs: 182160,
          uri: 'spotify:track:someone',
        ),
        SpotifyPlaylistTrack(
          title: 'How to Save a Life',
          subtitle: 'The Fray',
          durationMs: 262533,
          uri: 'spotify:track:fray',
        ),
        SpotifyPlaylistTrack(
          title: 'Obscure Missing Song',
          subtitle: 'Nobody',
          durationMs: 120000,
        ),
      ],
    );

    final music = _FakeMusicRepository({
      'Someone You Loved Lewis Capaldi': [
        song(
          id: 'vid_someone',
          title: 'Someone You Loved',
          artist: 'Lewis Capaldi',
          duration: 182,
        ),
      ],
      'How to Save a Life The Fray': [
        song(
          id: 'vid_fray',
          title: 'How to Save a Life',
          artist: 'The Fray',
          duration: 262,
        ),
      ],
    });

    final useCase = ImportSpotifyPlaylistUseCase(
      (_) async => snapshot,
      music,
      library,
      searchSpacing: Duration.zero,
    );

    final progress = <(int, int)>[];
    final result = await useCase.execute(
      snapshot.id,
      onProgress: (current, total) => progress.add((current, total)),
    );

    expect(result.source, PlaylistImportKind.spotify);
    expect(result.name, 'myLib');
    expect(result.importedCount, 2);
    expect(result.skippedCount, 1);
    expect(progress.last, (3, 3));

    expect(library.playlists, hasLength(1));
    expect(library.playlists.first.name, 'myLib');
    expect(library.playlists.first.description, contains('Spotify'));
    expect(library.playlists.first.isLinked, isTrue);
    expect(library.playlists.first.sourceKind, 'spotify');
    expect(library.playlists.first.remoteId, snapshot.id);
    expect(library.spotifyCache.containsKey('spotify:track:someone'), isTrue);

    expect(library.entries.map((e) => e.videoId), ['vid_someone', 'vid_fray']);
    expect(library.entries.first.title, 'Someone You Loved');
  });

  test(
    'persists artistsJson when YouTube Music credits multiple artists',
    () async {
      const snapshot = SpotifyPlaylistSnapshot(
        id: 'collabcollabcollabcoll1',
        name: 'feats',
        tracks: [
          SpotifyPlaylistTrack(
            title: "It Wasn't Me",
            subtitle: 'Shaggy, Rik Rok',
            durationMs: 227600,
          ),
        ],
      );
      final useCase = ImportSpotifyPlaylistUseCase(
        (_) async => snapshot,
        _FakeMusicRepository({
          "It Wasn't Me Shaggy": [
            song(
              id: 'vid_shaggy',
              title: "It Wasn't Me",
              artist: 'Shaggy',
              duration: 227,
              artists: [
                ArtistBasic(name: 'Shaggy', artistId: 'UC_shaggy'),
                ArtistBasic(name: 'Rik Rok', artistId: 'UC_rikrok'),
              ],
            ),
          ],
        }),
        library,
        searchSpacing: Duration.zero,
      );

      await useCase.execute(snapshot.id);
      expect(library.entries, hasLength(1));
      expect(library.entries.first.artistsJson, isNotNull);
      expect(library.entries.first.artistsJson, contains('Shaggy'));
      expect(library.entries.first.artistsJson, contains('Rik Rok'));
      expect(library.entries.first.artistsJson, contains('UC_shaggy'));
      expect(library.entries.first.artist, contains('Shaggy'));
    },
  );

  test(
    'skips duplicate YouTube ids so the playlist PK is not violated',
    () async {
      const snapshot = SpotifyPlaylistSnapshot(
        id: 'dupedupedupedupedupedu1',
        name: 'dupes',
        tracks: [
          SpotifyPlaylistTrack(
            title: 'Reason',
            subtitle: 'P!nk',
            durationMs: 242000,
          ),
          SpotifyPlaylistTrack(
            title: 'Reason',
            subtitle: 'P!nk',
            durationMs: 242000,
          ),
        ],
      );

      final hit = song(
        id: 'same',
        title: 'Just Give Me a Reason',
        artist: 'P!nk',
      );
      final useCase = ImportSpotifyPlaylistUseCase(
        (_) async => snapshot,
        _FakeMusicRepository({
          'Reason P!nk': [hit],
        }),
        library,
        searchSpacing: Duration.zero,
      );

      final result = await useCase.execute(snapshot.id);
      expect(result.importedCount, 1);
      expect(result.skippedCount, 1);
      expect(library.entries, hasLength(1));
    },
  );

  test('throws when no Spotify track can be matched', () async {
    const snapshot = SpotifyPlaylistSnapshot(
      id: 'emptyemptyemptyemptyem1',
      name: 'empty',
      tracks: [SpotifyPlaylistTrack(title: 'Nope', subtitle: 'Ghost')],
    );
    final useCase = ImportSpotifyPlaylistUseCase(
      (_) async => snapshot,
      _FakeMusicRepository(const {}),
      library,
      searchSpacing: Duration.zero,
    );

    await expectLater(useCase.execute(snapshot.id), throwsA(isA<Exception>()));
    expect(library.playlists, isEmpty);
  });

  test('dedupes re-import of an already linked Spotify playlist', () async {
    library.playlists.add(
      LocalPlaylistModel(
        id: 9,
        name: 'Existing',
        createdAt: DateTime(2024),
        sourceKind: 'spotify',
        remoteId: '5PlaEJOgemuwJGdHmCTAxg',
        remoteName: 'Existing',
        linkStatus: PlaylistLinkStatus.linked,
      ),
    );

    final useCase = ImportSpotifyPlaylistUseCase(
      (_) async => throw StateError('should not fetch'),
      _FakeMusicRepository(const {}),
      library,
      searchSpacing: Duration.zero,
    );

    await expectLater(
      useCase.execute('5PlaEJOgemuwJGdHmCTAxg'),
      throwsA(
        isA<PlaylistAlreadyLinkedException>().having(
          (e) => e.localPlaylistId,
          'localPlaylistId',
          9,
        ),
      ),
    );
  });

  test(
    'RefreshLinkedPlaylistUseCase replaces entries and reports diff',
    () async {
      final playlistId = await library.createPlaylist(
        'Late Night',
        sourceKind: 'spotify',
        remoteId: 'pl1',
        remoteName: 'Late Night',
        linkStatus: PlaylistLinkStatus.linked,
      );
      await library.addEntry(playlistId, 'old', 0, title: 'Old');
      await library.addEntry(playlistId, 'keep', 1, title: 'Keep');

      const snapshot = SpotifyPlaylistSnapshot(
        id: 'pl1',
        name: 'Late Night Drive',
        tracks: [
          SpotifyPlaylistTrack(
            title: 'Keep',
            subtitle: 'A',
            uri: 'spotify:track:keep',
          ),
          SpotifyPlaylistTrack(
            title: 'New',
            subtitle: 'B',
            uri: 'spotify:track:new',
          ),
        ],
      );

      library.spotifyCache['spotify:track:keep'] = 'keep';
      library.spotifyCache['spotify:track:new'] = 'new';

      final useCase = RefreshLinkedPlaylistUseCase(
        _FakeMusicRepository(const {}),
        library,
        fetchSpotify: (_) async => snapshot,
        searchSpacing: Duration.zero,
      );

      final result = await useCase.execute(playlistId);
      expect(result.added, 1);
      expect(result.removed, 1);
      expect(result.reordered, isFalse);
      expect(result.nameUpdated, isTrue);
      expect(library.playlists.first.name, 'Late Night Drive');
      expect(library.entries.map((e) => e.videoId), ['keep', 'new']);
    },
  );

  test('RefreshLinkedPlaylistUseCase preserves renamed local title', () async {
    final playlistId = await library.createPlaylist(
      'My rename',
      sourceKind: 'spotify',
      remoteId: 'pl2',
      remoteName: 'Original Remote',
      linkStatus: PlaylistLinkStatus.linked,
    );
    await library.addEntry(playlistId, 'a', 0);

    const snapshot = SpotifyPlaylistSnapshot(
      id: 'pl2',
      name: 'Remote Changed',
      tracks: [
        SpotifyPlaylistTrack(title: 'A', subtitle: 'X', uri: 'spotify:track:a'),
      ],
    );
    library.spotifyCache['spotify:track:a'] = 'a';

    final useCase = RefreshLinkedPlaylistUseCase(
      _FakeMusicRepository(const {}),
      library,
      fetchSpotify: (_) async => snapshot,
      searchSpacing: Duration.zero,
    );

    final result = await useCase.execute(playlistId);
    expect(result.nameUpdated, isFalse);
    expect(library.playlists.first.name, 'My rename');
    expect(library.playlists.first.remoteName, 'Remote Changed');
  });

  test('ImportRemotePlaylistUseCase routes Spotify URLs', () async {
    const snapshot = SpotifyPlaylistSnapshot(
      id: '5PlaEJOgemuwJGdHmCTAxg',
      name: 'myLib',
      tracks: [
        SpotifyPlaylistTrack(
          title: 'Someone You Loved',
          subtitle: 'Lewis Capaldi',
          durationMs: 182160,
        ),
      ],
    );
    final remote = ImportRemotePlaylistUseCase(
      SyncYoutubePlaylistUseCase(_FakeMusicRepository(const {}), library),
      ImportSpotifyPlaylistUseCase(
        (_) async => snapshot,
        _FakeMusicRepository({
          'Someone You Loved Lewis Capaldi': [
            song(
              id: 'vid_someone',
              title: 'Someone You Loved',
              artist: 'Lewis Capaldi',
            ),
          ],
        }),
        library,
        searchSpacing: Duration.zero,
      ),
    );

    final result = await remote.execute(
      'https://open.spotify.com/playlist/5PlaEJOgemuwJGdHmCTAxg?si=240a7072fc3e4e58',
    );
    expect(result.source, PlaylistImportKind.spotify);
    expect(result.importedCount, 1);
  });

  test('ImportRemotePlaylistUseCase rejects unknown URLs', () async {
    final remote = ImportRemotePlaylistUseCase(
      SyncYoutubePlaylistUseCase(_FakeMusicRepository(const {}), library),
      ImportSpotifyPlaylistUseCase(
        (_) async => throw StateError('not used'),
        _FakeMusicRepository(const {}),
        library,
        searchSpacing: Duration.zero,
      ),
    );
    expect(
      () => remote.execute('https://example.com/not-a-playlist'),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class _FakeMusicRepository extends Fake implements MusicRepository {
  _FakeMusicRepository(this._results);

  final Map<String, List<SongDetailed>> _results;

  @override
  Future<List<SongDetailed>> searchSongs(String query, {int limit = 20}) async {
    return _results[query] ?? const [];
  }
}

class _FakeLibraryRepository extends Fake implements LibraryRepository {
  int _nextId = 1;
  final List<LocalPlaylistModel> playlists = [];
  final List<PlaylistEntryModel> entries = [];
  final Map<String, String> spotifyCache = {};

  @override
  Future<int> createPlaylist(
    String name, {
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String linkStatus = 'local',
    DateTime? lastSyncedAt,
  }) async {
    final id = _nextId++;
    playlists.add(
      LocalPlaylistModel(
        id: id,
        name: name,
        description: description,
        createdAt: DateTime.now(),
        sourceKind: sourceKind,
        remoteId: remoteId,
        remoteName: remoteName,
        lastSyncedAt: lastSyncedAt,
        linkStatus: linkStatus,
      ),
    );
    return id;
  }

  @override
  Future<LocalPlaylistModel?> getPlaylist(int id) async {
    return playlists.cast<LocalPlaylistModel?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => null,
    );
  }

  @override
  Future<LocalPlaylistModel?> findLinkedPlaylist(
    String sourceKind,
    String remoteId,
  ) async {
    return playlists.cast<LocalPlaylistModel?>().firstWhere(
      (p) =>
          p?.sourceKind == sourceKind &&
          p?.remoteId == remoteId &&
          p?.linkStatus == PlaylistLinkStatus.linked,
      orElse: () => null,
    );
  }

  @override
  Future<void> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String? linkStatus,
    DateTime? lastSyncedAt,
  }) async {
    final index = playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final p = playlists[index];
    playlists[index] = LocalPlaylistModel(
      id: p.id,
      name: name ?? p.name,
      description: description ?? p.description,
      createdAt: p.createdAt,
      sourceKind: sourceKind ?? p.sourceKind,
      remoteId: remoteId ?? p.remoteId,
      remoteName: remoteName ?? p.remoteName,
      lastSyncedAt: lastSyncedAt ?? p.lastSyncedAt,
      linkStatus: linkStatus ?? p.linkStatus,
    );
  }

  @override
  Future<void> replacePlaylistEntries(
    int playlistId,
    List<PlaylistEntryModel> newEntries,
  ) async {
    entries.removeWhere((e) => e.playlistId == playlistId);
    for (var i = 0; i < newEntries.length; i++) {
      final e = newEntries[i];
      entries.add(
        PlaylistEntryModel(
          playlistId: playlistId,
          videoId: e.videoId,
          position: i,
          title: e.title,
          artist: e.artist,
          artistsJson: e.artistsJson,
          thumbnailUrl: e.thumbnailUrl,
          duration: e.duration,
          isVideo: e.isVideo,
          isExplicit: e.isExplicit,
        ),
      );
    }
  }

  @override
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? artistsJson,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) async {
    entries.add(
      PlaylistEntryModel(
        playlistId: playlistId,
        videoId: videoId,
        position: position,
        title: title,
        artist: artist,
        artistsJson: artistsJson,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        isExplicit: isExplicit,
      ),
    );
  }

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async => playlists;

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async =>
      entries.where((e) => e.playlistId == playlistId).toList();

  @override
  Future<PlaylistEntryModel?> getCachedSpotifyMatch(
    String spotifyTrackUri,
  ) async {
    final videoId = spotifyCache[spotifyTrackUri];
    if (videoId == null) return null;
    return PlaylistEntryModel(playlistId: 0, videoId: videoId, position: 0);
  }

  @override
  Future<void> upsertSpotifyMatch({
    required String spotifyTrackUri,
    required String videoId,
    String? title,
    double? score,
  }) async {
    spotifyCache[spotifyTrackUri] = videoId;
  }
}
