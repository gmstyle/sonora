import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';

void main() {
  late AppDatabase db;
  late LibraryDao libraryDao;
  late PlaylistsDao playlistsDao;
  late DownloadsDao downloadsDao;
  late HistoryDao historyDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    libraryDao = LibraryDao(db);
    playlistsDao = PlaylistsDao(db);
    downloadsDao = DownloadsDao(db);
    historyDao = HistoryDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LibraryDao', () {
    test('insert and retrieve liked song', () async {
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('test_video'),
        title: Value('Test Song'),
        artist: Value('Test Artist'),
        thumbnailUrl: Value('https://example.com/thumb.jpg'),
        addedAt: Value(DateTime.now()),
      ));

      final songs = await libraryDao.getAllLikedSongs();
      expect(songs.length, 1);
      expect(songs.first.videoId, 'test_video');
      expect(songs.first.title, 'Test Song');
    });

    test('delete liked song', () async {
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('test_video'),
        title: Value('Test Song'),
        artist: Value('Test Artist'),
        addedAt: Value(DateTime.now()),
      ));

      await libraryDao.deleteLikedSong('test_video');
      final songs = await libraryDao.getAllLikedSongs();
      expect(songs, isEmpty);
    });

    test('insert and retrieve followed artist', () async {
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_1'),
        name: Value('Test Artist'),
        thumbnailUrl: Value('https://example.com/artist.jpg'),
      ));

      final artists = await libraryDao.getAllFollowedArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Test Artist');
    });

    test('delete followed artist', () async {
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_1'),
        name: Value('Test Artist'),
      ));

      await libraryDao.deleteFollowedArtist('artist_1');
      final artists = await libraryDao.getAllFollowedArtists();
      expect(artists, isEmpty);
    });
  });

  group('PlaylistsDao', () {
    test('create and retrieve playlist', () async {
      await playlistsDao.createPlaylist('My Playlist',
          description: 'A test playlist');
      final playlists = await playlistsDao.getAllPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'My Playlist');
      expect(playlists.first.description, 'A test playlist');
    });

    test('delete playlist removes entries', () async {
      final id = await playlistsDao.createPlaylist('Test');
      await playlistsDao.addEntry(id, 'video_1', 0);
      await playlistsDao.addEntry(id, 'video_2', 1);

      await playlistsDao.deletePlaylist(id);
      final playlists = await playlistsDao.getAllPlaylists();
      expect(playlists, isEmpty);
    });

    test('add and retrieve playlist entries ordered', () async {
      final id = await playlistsDao.createPlaylist('Test');
      await playlistsDao.addEntry(id, 'video_2', 1);
      await playlistsDao.addEntry(id, 'video_1', 0);

      final entries = await playlistsDao.getPlaylistEntries(id);
      expect(entries.length, 2);
      expect(entries.first.videoId, 'video_1');
      expect(entries.last.videoId, 'video_2');
    });
  });

  group('DownloadsDao', () {
    test('insert and retrieve download', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        status: Value('pending'),
      ));

      final downloads = await downloadsDao.getAllDownloads();
      expect(downloads.length, 1);
      expect(downloads.first.status, 'pending');
    });

    test('update download status', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        status: Value('pending'),
      ));

      await downloadsDao.updateStatus('video_1', 'completed');
      final download = await downloadsDao.getDownload('video_1');
      expect(download?.status, 'completed');
    });
  });

  group('HistoryDao', () {
    test('record and retrieve play history', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');
      await historyDao.recordPlay('video_2', 'Song 2', 'Artist 2');

      final history = await historyDao.getRecentHistory();
      expect(history.length, 2);
      final titles = history.map((h) => h.title).toSet();
      expect(titles, contains('Song 1'));
      expect(titles, contains('Song 2'));
    });

    test('increment play count on replay', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');

      final history = await historyDao.getRecentHistory();
      expect(history.length, 1);
      expect(history.first.playCount, 2);
    });

    test('clear history', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');
      await historyDao.clearHistory();

      final history = await historyDao.getRecentHistory();
      expect(history, isEmpty);
    });

    test('insert and retrieve search history', () async {
      await historyDao.insertSearchEntry('test query');
      await historyDao.insertSearchEntry('another query');

      final searches = await historyDao.getRecentSearches();
      expect(searches.length, 2);
      final queries = searches.map((s) => s.query).toSet();
      expect(queries, contains('test query'));
      expect(queries, contains('another query'));
    });

    test('clear search history', () async {
      await historyDao.insertSearchEntry('test');
      await historyDao.clearSearchHistory();

      final searches = await historyDao.getRecentSearches();
      expect(searches, isEmpty);
    });
  });
}
