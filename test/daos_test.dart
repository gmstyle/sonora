import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

    test('getLikedSong returns null for non-existing videoId', () async {
      final song = await libraryDao.getLikedSong('nonexistent');
      expect(song, isNull);
    });

    test('getLikedSong returns the correct song', () async {
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('video_1'),
        title: Value('Song 1'),
        artist: Value('Artist 1'),
        addedAt: Value(DateTime.now()),
      ));
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('video_2'),
        title: Value('Song 2'),
        artist: Value('Artist 2'),
        addedAt: Value(DateTime.now()),
      ));

      final song = await libraryDao.getLikedSong('video_1');
      expect(song, isNotNull);
      expect(song!.videoId, 'video_1');
      expect(song.title, 'Song 1');

      final nullSong = await libraryDao.getLikedSong('video_3');
      expect(nullSong, isNull);
    });

    test('insert likesong upsert on conflict', () async {
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('video_1'),
        title: Value('Original'),
        artist: Value('Artist'),
        addedAt: Value(DateTime.now()),
      ));
      await libraryDao.insertLikedSong(LikedSongsCompanion(
        videoId: Value('video_1'),
        title: Value('Updated'),
        artist: Value('Artist'),
        addedAt: Value(DateTime.now()),
      ));

      final songs = await libraryDao.getAllLikedSongs();
      expect(songs.length, 1);
      expect(songs.first.title, 'Updated');
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

    test('delete non-existing liked song does not error', () async {
      await libraryDao.deleteLikedSong('nonexistent');
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

    test('getFollowedArtist returns null for non-existing artistId', () async {
      final artist = await libraryDao.getFollowedArtist('nonexistent');
      expect(artist, isNull);
    });

    test('getFollowedArtist returns the correct artist', () async {
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_1'),
        name: Value('Artist 1'),
      ));
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_2'),
        name: Value('Artist 2'),
      ));

      final artist = await libraryDao.getFollowedArtist('artist_1');
      expect(artist, isNotNull);
      expect(artist!.name, 'Artist 1');

      final nullArtist = await libraryDao.getFollowedArtist('artist_3');
      expect(nullArtist, isNull);
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

    test('delete non-existing followed artist does not error', () async {
      await libraryDao.deleteFollowedArtist('nonexistent');
      final artists = await libraryDao.getAllFollowedArtists();
      expect(artists, isEmpty);
    });

    test('followed artist upsert on conflict', () async {
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_1'),
        name: Value('Original'),
      ));
      await libraryDao.insertFollowedArtist(FollowedArtistsCompanion(
        artistId: Value('artist_1'),
        name: Value('Updated'),
      ));

      final artists = await libraryDao.getAllFollowedArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Updated');
    });

    group('LikedAlbums', () {
      test('insert and retrieve liked album', () async {
        await libraryDao.insertLikedAlbum(LikedAlbumsCompanion(
          albumId: Value('album_1'),
          name: Value('Test Album'),
          artistName: Value('Test Artist'),
          thumbnailUrl: Value('https://example.com/album.jpg'),
          year: Value(2024),
          addedAt: Value(DateTime.now()),
        ));

        final albums = await libraryDao.getAllLikedAlbums();
        expect(albums.length, 1);
        expect(albums.first.albumId, 'album_1');
        expect(albums.first.name, 'Test Album');
        expect(albums.first.year, 2024);
      });

      test('getLikedAlbum returns null for non-existing albumId', () async {
        final album = await libraryDao.getLikedAlbum('nonexistent');
        expect(album, isNull);
      });

      test('getLikedAlbum returns correct album', () async {
        await libraryDao.insertLikedAlbum(LikedAlbumsCompanion(
          albumId: Value('album_1'),
          name: Value('Album 1'),
          artistName: Value('Artist'),
          addedAt: Value(DateTime.now()),
        ));

        final album = await libraryDao.getLikedAlbum('album_1');
        expect(album, isNotNull);
        expect(album!.name, 'Album 1');

        final nullAlbum = await libraryDao.getLikedAlbum('album_2');
        expect(nullAlbum, isNull);
      });

      test('delete liked album', () async {
        await libraryDao.insertLikedAlbum(LikedAlbumsCompanion(
          albumId: Value('album_1'),
          name: Value('Test Album'),
          artistName: Value('Artist'),
          addedAt: Value(DateTime.now()),
        ));

        await libraryDao.deleteLikedAlbum('album_1');
        final albums = await libraryDao.getAllLikedAlbums();
        expect(albums, isEmpty);
      });

      test('liked album upsert on conflict', () async {
        await libraryDao.insertLikedAlbum(LikedAlbumsCompanion(
          albumId: Value('album_1'),
          name: Value('Original'),
          artistName: Value('Artist'),
          addedAt: Value(DateTime.now()),
        ));
        await libraryDao.insertLikedAlbum(LikedAlbumsCompanion(
          albumId: Value('album_1'),
          name: Value('Updated'),
          artistName: Value('Artist'),
          addedAt: Value(DateTime.now()),
        ));

        final albums = await libraryDao.getAllLikedAlbums();
        expect(albums.length, 1);
        expect(albums.first.name, 'Updated');
      });
    });

    group('LikedPlaylists', () {
      test('insert and retrieve liked playlist', () async {
        await libraryDao.insertLikedPlaylist(LikedPlaylistsCompanion(
          playlistId: Value('playlist_1'),
          name: Value('Test Playlist'),
          thumbnailUrl: Value('https://example.com/playlist.jpg'),
          videoCount: Value(10),
          addedAt: Value(DateTime.now()),
        ));

        final playlists = await libraryDao.getAllLikedPlaylists();
        expect(playlists.length, 1);
        expect(playlists.first.playlistId, 'playlist_1');
        expect(playlists.first.name, 'Test Playlist');
        expect(playlists.first.videoCount, 10);
      });

      test('getLikedPlaylist returns null for non-existing playlistId', () async {
        final playlist =
            await libraryDao.getLikedPlaylist('nonexistent');
        expect(playlist, isNull);
      });

      test('getLikedPlaylist returns correct playlist', () async {
        await libraryDao.insertLikedPlaylist(LikedPlaylistsCompanion(
          playlistId: Value('p1'),
          name: Value('Playlist 1'),
          addedAt: Value(DateTime.now()),
        ));

        final playlist = await libraryDao.getLikedPlaylist('p1');
        expect(playlist, isNotNull);
        expect(playlist!.name, 'Playlist 1');

        final nullPlaylist = await libraryDao.getLikedPlaylist('p2');
        expect(nullPlaylist, isNull);
      });

      test('delete liked playlist', () async {
        await libraryDao.insertLikedPlaylist(LikedPlaylistsCompanion(
          playlistId: Value('playlist_1'),
          name: Value('Test Playlist'),
          addedAt: Value(DateTime.now()),
        ));

        await libraryDao.deleteLikedPlaylist('playlist_1');
        final playlists = await libraryDao.getAllLikedPlaylists();
        expect(playlists, isEmpty);
      });

      test('liked playlist upsert on conflict', () async {
        await libraryDao.insertLikedPlaylist(LikedPlaylistsCompanion(
          playlistId: Value('p1'),
          name: Value('Original'),
          addedAt: Value(DateTime.now()),
        ));
        await libraryDao.insertLikedPlaylist(LikedPlaylistsCompanion(
          playlistId: Value('p1'),
          name: Value('Updated'),
          addedAt: Value(DateTime.now()),
        ));

        final playlists = await libraryDao.getAllLikedPlaylists();
        expect(playlists.length, 1);
        expect(playlists.first.name, 'Updated');
      });
    });

    test('empty liked songs list', () async {
      final songs = await libraryDao.getAllLikedSongs();
      expect(songs, isEmpty);
    });

    test('empty followed artists list', () async {
      final artists = await libraryDao.getAllFollowedArtists();
      expect(artists, isEmpty);
    });

    test('empty liked albums list', () async {
      final albums = await libraryDao.getAllLikedAlbums();
      expect(albums, isEmpty);
    });

    test('empty liked playlists list', () async {
      final playlists = await libraryDao.getAllLikedPlaylists();
      expect(playlists, isEmpty);
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

    test('getPlaylist returns null for non-existing id', () async {
      final playlist = await playlistsDao.getPlaylist(999);
      expect(playlist, isNull);
    });

    test('getPlaylist returns correct playlist', () async {
      final id =
          await playlistsDao.createPlaylist('Test', description: 'desc');
      final playlist = await playlistsDao.getPlaylist(id);
      expect(playlist, isNotNull);
      expect(playlist!.name, 'Test');
      expect(playlist.description, 'desc');
    });

    test('updatePlaylist updates name only', () async {
      final id = await playlistsDao.createPlaylist('Original');
      await playlistsDao.updatePlaylist(id, name: 'Updated');
      final playlist = await playlistsDao.getPlaylist(id);
      expect(playlist!.name, 'Updated');
    });

    test('updatePlaylist updates description only', () async {
      final id =
          await playlistsDao.createPlaylist('Test', description: 'Original');
      await playlistsDao.updatePlaylist(id, description: 'Updated');
      final playlist = await playlistsDao.getPlaylist(id);
      expect(playlist!.description, 'Updated');
    });

    test('updatePlaylist updates both name and description', () async {
      final id = await playlistsDao.createPlaylist('Original Name',
          description: 'Original Desc');
      await playlistsDao.updatePlaylist(
        id,
        name: 'New Name',
        description: 'New Desc',
      );
      final playlist = await playlistsDao.getPlaylist(id);
      expect(playlist!.name, 'New Name');
      expect(playlist.description, 'New Desc');
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

    test('removeEntry removes only the specified entry', () async {
      final id = await playlistsDao.createPlaylist('Test');
      await playlistsDao.addEntry(id, 'video_1', 0);
      await playlistsDao.addEntry(id, 'video_2', 1);
      await playlistsDao.addEntry(id, 'video_3', 2);

      await playlistsDao.removeEntry(id, 'video_2');
      final entries = await playlistsDao.getPlaylistEntries(id);
      expect(entries.length, 2);
      expect(entries.map((e) => e.videoId), contains('video_1'));
      expect(entries.map((e) => e.videoId), contains('video_3'));
      expect(entries.map((e) => e.videoId), isNot(contains('video_2')));
    });

    test('reorderEntries updates positions', () async {
      final id = await playlistsDao.createPlaylist('Test');
      await playlistsDao.addEntry(id, 'video_a', 0);
      await playlistsDao.addEntry(id, 'video_b', 1);
      await playlistsDao.addEntry(id, 'video_c', 2);

      await playlistsDao.reorderEntries(id, [
        'video_c',
        'video_a',
        'video_b',
      ]);
      final entries = await playlistsDao.getPlaylistEntries(id);
      expect(entries.length, 3);
      expect(entries[0].videoId, 'video_c');
      expect(entries[1].videoId, 'video_a');
      expect(entries[2].videoId, 'video_b');
    });

    test('empty playlist entries', () async {
      final id = await playlistsDao.createPlaylist('Empty');
      final entries = await playlistsDao.getPlaylistEntries(id);
      expect(entries, isEmpty);
    });

    test('createPlaylist without description sets null', () async {
      final id = await playlistsDao.createPlaylist('No Desc');
      final playlist = await playlistsDao.getPlaylist(id);
      expect(playlist!.description, isNull);
    });

    test('getAllPlaylists returns empty when no playlists', () async {
      final playlists = await playlistsDao.getAllPlaylists();
      expect(playlists, isEmpty);
    });
  });

  group('DownloadsDao', () {
    test('insert and retrieve download', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Test Song'),
        artist: Value('Test Artist'),
        status: Value('pending'),
        thumbnailUrl: Value('https://example.com/thumb.jpg'),
      ));

      final downloads = await downloadsDao.getAllDownloads();
      expect(downloads.length, 1);
      expect(downloads.first.status, 'pending');
      expect(downloads.first.title, 'Test Song');
    });

    test('getDownload returns null for non-existing videoId', () async {
      final download = await downloadsDao.getDownload('nonexistent');
      expect(download, isNull);
    });

    test('getDownload returns correct download', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Song 1'),
        artist: Value('Artist 1'),
        status: Value('downloading'),
      ));
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_2'),
        title: Value('Song 2'),
        artist: Value('Artist 2'),
        status: Value('completed'),
      ));

      final d1 = await downloadsDao.getDownload('video_1');
      expect(d1, isNotNull);
      expect(d1!.status, 'downloading');
      expect(d1.videoId, 'video_1');

      final dMissing = await downloadsDao.getDownload('video_3');
      expect(dMissing, isNull);
    });

    test('update download status', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Test Song'),
        artist: Value('Test Artist'),
        status: Value('pending'),
      ));

      await downloadsDao.updateStatus('video_1', 'completed');
      final download = await downloadsDao.getDownload('video_1');
      expect(download?.status, 'completed');
    });

    test('updateStatus for non-existing does not throw', () async {
      await downloadsDao.updateStatus('nonexistent', 'completed');
    });

    test('delete download removes the record', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Song 1'),
        artist: Value('Artist 1'),
        status: Value('completed'),
      ));
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_2'),
        title: Value('Song 2'),
        artist: Value('Artist 2'),
        status: Value('pending'),
      ));

      await downloadsDao.deleteDownload('video_1');
      final downloads = await downloadsDao.getAllDownloads();
      expect(downloads.length, 1);
      expect(downloads.first.videoId, 'video_2');
    });

    test('deleteDownload for non-existing does not throw', () async {
      await downloadsDao.deleteDownload('nonexistent');
    });

    test('empty downloads list', () async {
      final downloads = await downloadsDao.getAllDownloads();
      expect(downloads, isEmpty);
    });

    test('upsert download replaces existing', () async {
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Original'),
        artist: Value('Artist'),
        status: Value('pending'),
      ));
      await downloadsDao.insertDownload(DownloadsCompanion(
        videoId: Value('video_1'),
        title: Value('Original'),
        artist: Value('Artist'),
        status: Value('completed'),
      ));

      final download = await downloadsDao.getDownload('video_1');
      expect(download!.status, 'completed');
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

    test('increment play count many times', () async {
      for (var i = 0; i < 5; i++) {
        await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');
      }

      final history = await historyDao.getRecentHistory();
      expect(history.length, 1);
      expect(history.first.playCount, 5);
    });

    test('clear history', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');
      await historyDao.clearHistory();

      final history = await historyDao.getRecentHistory();
      expect(history, isEmpty);
    });

    test('recordPlay with thumbnail URL', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1',
          thumbnailUrl: 'https://example.com/thumb.jpg');

      final history = await historyDao.getRecentHistory();
      expect(history.length, 1);
      expect(history.first.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('recordPlay thumbnail persists across replays', () async {
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1',
          thumbnailUrl: 'https://example.com/thumb.jpg');
      await historyDao.recordPlay('video_1', 'Song 1', 'Artist 1');

      final history = await historyDao.getRecentHistory();
      expect(history.length, 1);
      expect(history.first.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('empty history list', () async {
      final history = await historyDao.getRecentHistory();
      expect(history, isEmpty);
    });

    test('getRecentHistory respects limit', () async {
      for (var i = 0; i < 10; i++) {
        await historyDao
            .recordPlay('video_$i', 'Song $i', 'Artist $i');
      }

      final limited = await historyDao.getRecentHistory(limit: 3);
      expect(limited.length, 3);
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

    test('empty search history', () async {
      final searches = await historyDao.getRecentSearches();
      expect(searches, isEmpty);
    });

    test('getRecentSearches respects limit', () async {
      for (var i = 0; i < 20; i++) {
        await historyDao.insertSearchEntry('query_$i');
      }

      final limited = await historyDao.getRecentSearches(limit: 5);
      expect(limited.length, 5);
    });
  });
}
