import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/models/playlist_import.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/playlist/import_remote_playlist_use_case.dart';
import 'package:sonora/domain/usecases/playlist/import_spotify_playlist_use_case.dart';
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
  }) {
    return SongDetailed(
      type: 'SONG',
      videoId: id,
      name: title,
      artist: ArtistBasic(name: artist),
      duration: duration,
      thumbnails: const [],
    );
  }

  test('imports matched Spotify tracks into a local playlist', () async {
    const snapshot = SpotifyPlaylistSnapshot(
      id: '5PlaEJOgemuwJGdHmCTAxg',
      name: 'myLib',
      tracks: [
        SpotifyPlaylistTrack(
          title: 'Someone You Loved',
          subtitle: 'Lewis Capaldi',
          durationMs: 182160,
        ),
        SpotifyPlaylistTrack(
          title: 'How to Save a Life',
          subtitle: 'The Fray',
          durationMs: 262533,
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

    expect(library.entries.map((e) => e.videoId), ['vid_someone', 'vid_fray']);
    expect(library.entries.first.title, 'Someone You Loved');
  });

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

  @override
  Future<int> createPlaylist(String name, {String? description}) async {
    final id = _nextId++;
    playlists.add(
      LocalPlaylistModel(
        id: id,
        name: name,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  @override
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
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
}
