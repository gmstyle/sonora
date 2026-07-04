import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/domain/models/library_models.dart';

void main() {
  late AppDatabase db;
  late LibraryRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Liked songs', () {
    test('toggleLikedSong inserts when not liked', () async {
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'video_1',
          title: 'Song 1',
          artist: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final songs = await repo.getAllLikedSongs();
      expect(songs.length, 1);
      expect(songs.first.videoId, 'video_1');
    });

    test('toggleLikedSong deletes when already liked', () async {
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'video_1',
          title: 'Song 1',
          artist: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'video_1',
          title: 'Song 1',
          artist: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final songs = await repo.getAllLikedSongs();
      expect(songs, isEmpty);
    });

    test('getLikedSong returns null when not liked', () async {
      final song = await repo.getLikedSong('nonexistent');
      expect(song, isNull);
    });

    test('getLikedSong returns mapped model', () async {
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'video_1',
          title: 'Song 1',
          artist: 'Artist 1',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final song = await repo.getLikedSong('video_1');
      expect(song, isNotNull);
      expect(song!.videoId, 'video_1');
      expect(song.title, 'Song 1');
      expect(song.artist, 'Artist 1');
      expect(song.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('getAllLikedSongs returns empty when none liked', () async {
      final songs = await repo.getAllLikedSongs();
      expect(songs, isEmpty);
    });

    test('deleteLikedSong removes the song', () async {
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'video_1',
          title: 'Song 1',
          artist: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.deleteLikedSong('video_1');

      final songs = await repo.getAllLikedSongs();
      expect(songs, isEmpty);
    });

    test('getAllLikedSongs returns multiple mapped models', () async {
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'v1',
          title: 'Song 1',
          artist: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.toggleLikedSong(
        LikedSongModel(
          videoId: 'v2',
          title: 'Song 2',
          artist: 'Artist 2',
          addedAt: DateTime.now(),
        ),
      );

      final songs = await repo.getAllLikedSongs();
      expect(songs.length, 2);
      expect(songs.map((s) => s.videoId), containsAll(['v1', 'v2']));
    });
  });

  group('Followed artists', () {
    test('toggleFollowedArtist inserts when not followed', () async {
      await repo.toggleFollowedArtist(
        FollowedArtistModel(
          artistId: 'artist_1',
          name: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final artists = await repo.getAllFollowedArtists();
      expect(artists.length, 1);
      expect(artists.first.artistId, 'artist_1');
    });

    test('toggleFollowedArtist deletes when already followed', () async {
      await repo.toggleFollowedArtist(
        FollowedArtistModel(
          artistId: 'artist_1',
          name: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.toggleFollowedArtist(
        FollowedArtistModel(
          artistId: 'artist_1',
          name: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final artists = await repo.getAllFollowedArtists();
      expect(artists, isEmpty);
    });

    test('getFollowedArtist returns null when not followed', () async {
      final artist = await repo.getFollowedArtist('nonexistent');
      expect(artist, isNull);
    });

    test('getFollowedArtist returns mapped model', () async {
      await repo.toggleFollowedArtist(
        FollowedArtistModel(
          artistId: 'artist_1',
          name: 'Artist 1',
          thumbnailUrl: 'https://example.com/artist.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final artist = await repo.getFollowedArtist('artist_1');
      expect(artist, isNotNull);
      expect(artist!.name, 'Artist 1');
      expect(artist.thumbnailUrl, 'https://example.com/artist.jpg');
    });

    test('getAllFollowedArtists returns empty when none followed', () async {
      final artists = await repo.getAllFollowedArtists();
      expect(artists, isEmpty);
    });
  });

  group('Liked albums', () {
    test('toggleLikedAlbum inserts when not liked', () async {
      await repo.toggleLikedAlbum(
        LikedAlbumModel(
          albumId: 'album_1',
          name: 'Album 1',
          artistName: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final albums = await repo.getAllLikedAlbums();
      expect(albums.length, 1);
      expect(albums.first.albumId, 'album_1');
    });

    test('toggleLikedAlbum deletes when already liked', () async {
      await repo.toggleLikedAlbum(
        LikedAlbumModel(
          albumId: 'album_1',
          name: 'Album 1',
          artistName: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.toggleLikedAlbum(
        LikedAlbumModel(
          albumId: 'album_1',
          name: 'Album 1',
          artistName: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );

      final albums = await repo.getAllLikedAlbums();
      expect(albums, isEmpty);
    });

    test('getLikedAlbum returns mapped model', () async {
      await repo.toggleLikedAlbum(
        LikedAlbumModel(
          albumId: 'album_1',
          name: 'Album 1',
          artistName: 'Artist 1',
          artistId: 'artist_1',
          year: 2024,
          thumbnailUrl: 'https://example.com/album.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final album = await repo.getLikedAlbum('album_1');
      expect(album, isNotNull);
      expect(album!.name, 'Album 1');
      expect(album.artistId, 'artist_1');
      expect(album.year, 2024);
    });

    test('getAllLikedAlbums returns empty when none liked', () async {
      final albums = await repo.getAllLikedAlbums();
      expect(albums, isEmpty);
    });

    test('deleteLikedAlbum removes the album', () async {
      await repo.toggleLikedAlbum(
        LikedAlbumModel(
          albumId: 'album_1',
          name: 'Album 1',
          artistName: 'Artist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.deleteLikedAlbum('album_1');

      final albums = await repo.getAllLikedAlbums();
      expect(albums, isEmpty);
    });
  });

  group('Liked playlists', () {
    test('toggleLikedPlaylist inserts when not liked', () async {
      await repo.toggleLikedPlaylist(
        LikedPlaylistModel(
          playlistId: 'p1',
          name: 'Playlist 1',
          addedAt: DateTime.now(),
        ),
      );

      final playlists = await repo.getAllLikedPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.playlistId, 'p1');
    });

    test('toggleLikedPlaylist deletes when already liked', () async {
      await repo.toggleLikedPlaylist(
        LikedPlaylistModel(
          playlistId: 'p1',
          name: 'Playlist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.toggleLikedPlaylist(
        LikedPlaylistModel(
          playlistId: 'p1',
          name: 'Playlist 1',
          addedAt: DateTime.now(),
        ),
      );

      final playlists = await repo.getAllLikedPlaylists();
      expect(playlists, isEmpty);
    });

    test('getLikedPlaylist returns mapped model', () async {
      await repo.toggleLikedPlaylist(
        LikedPlaylistModel(
          playlistId: 'p1',
          name: 'Playlist 1',
          videoCount: 5,
          thumbnailUrl: 'https://example.com/playlist.jpg',
          addedAt: DateTime.now(),
        ),
      );

      final playlist = await repo.getLikedPlaylist('p1');
      expect(playlist, isNotNull);
      expect(playlist!.name, 'Playlist 1');
      expect(playlist.videoCount, 5);
    });

    test('getAllLikedPlaylists returns empty when none liked', () async {
      final playlists = await repo.getAllLikedPlaylists();
      expect(playlists, isEmpty);
    });

    test('deleteLikedPlaylist removes the playlist', () async {
      await repo.toggleLikedPlaylist(
        LikedPlaylistModel(
          playlistId: 'p1',
          name: 'Playlist 1',
          addedAt: DateTime.now(),
        ),
      );
      await repo.deleteLikedPlaylist('p1');

      final playlists = await repo.getAllLikedPlaylists();
      expect(playlists, isEmpty);
    });
  });

  group('Local playlists', () {
    test('createPlaylist and getAllPlaylists', () async {
      await repo.createPlaylist('My Playlist');
      final all = await repo.getAllPlaylists();
      expect(all.length, 1);
      expect(all.first.name, 'My Playlist');
    });

    test('updatePlaylist changes name', () async {
      final all = await repo.getAllPlaylists();
      expect(all, isEmpty);

      await repo.createPlaylist('Original');
      final playlists = await repo.getAllPlaylists();
      await repo.updatePlaylist(playlists.first.id, name: 'Updated');

      final updated = await repo.getAllPlaylists();
      expect(updated.first.name, 'Updated');
    });

    test('deletePlaylist removes playlist', () async {
      await repo.createPlaylist('To Delete');
      var all = await repo.getAllPlaylists();
      expect(all.length, 1);

      await repo.deletePlaylist(all.first.id);
      all = await repo.getAllPlaylists();
      expect(all, isEmpty);
    });

    test('addEntry, getPlaylistEntries, removeEntry', () async {
      await repo.createPlaylist('Test');
      final playlists = await repo.getAllPlaylists();
      final pid = playlists.first.id;

      await repo.addEntry(pid, 'video_1', 0);
      await repo.addEntry(pid, 'video_2', 1);

      var entries = await repo.getPlaylistEntries(pid);
      expect(entries.length, 2);
      expect(entries.first.videoId, 'video_1');

      await repo.removeEntry(pid, 'video_1');
      entries = await repo.getPlaylistEntries(pid);
      expect(entries.length, 1);
      expect(entries.first.videoId, 'video_2');
    });
  });

  group('Downloads', () {
    test('getAllDownloads returns empty initially', () async {
      final downloads = await repo.getAllDownloads();
      expect(downloads, isEmpty);
    });

    test('insert and get download', () async {
      await repo.insertDownload(
        videoId: 'v1',
        title: 'Song 1',
        artist: 'Artist 1',
        status: 'pending',
      );
      final retrieved = await repo.getDownload('v1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Song 1');
      expect(retrieved.status, 'pending');
    });

    test('deleteDownload removes the download', () async {
      await repo.insertDownload(
        videoId: 'v1',
        title: 'Song 1',
        artist: 'Artist 1',
        status: 'completed',
      );
      await repo.deleteDownload('v1');
      final downloads = await repo.getAllDownloads();
      expect(downloads, isEmpty);
    });
  });

  group('History', () {
    test('getRecentHistory returns results', () async {
      await repo.recordPlay(
        'v1',
        'Song 1',
        'Artist 1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      final history = await repo.getRecentHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Song 1');
    });

    test('clearHistory empties the table', () async {
      await repo.recordPlay('v1', 'Song 1', 'Artist 1');
      await repo.clearHistory();
      final history = await repo.getRecentHistory();
      expect(history, isEmpty);
    });

    test('insertSearchEntry and getRecentSearches', () async {
      await repo.insertSearchEntry('query 1');
      final searches = await repo.getRecentSearches();
      expect(searches.length, 1);
      expect(searches.first.query, 'query 1');
    });

    test('clearSearchHistory empties the table', () async {
      await repo.insertSearchEntry('query');
      await repo.clearSearchHistory();
      final searches = await repo.getRecentSearches();
      expect(searches, isEmpty);
    });
  });
}
