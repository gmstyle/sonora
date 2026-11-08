import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/presentation/features/search/library_matches.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  LibraryMatches filter(String query) {
    return filterLibraryCollections(
      query: query,
      songs: [
        LikedSongModel(
          videoId: 'song1',
          title: 'Wish I Didn\'t Miss You',
          artist: 'Angie Stone',
          addedAt: now,
        ),
        LikedSongModel(
          videoId: 'song2',
          title: 'Other',
          artist: 'Someone Else',
          addedAt: now,
        ),
      ],
      artists: [
        FollowedArtistModel(
          artistId: 'artist1',
          name: 'Angie Stone',
          addedAt: now,
        ),
      ],
      playlists: [
        LocalPlaylistModel(
          id: 1,
          name: 'Night drive',
          description: 'Angie Stone and friends',
          createdAt: now,
        ),
      ],
      likedPlaylists: [
        LikedPlaylistModel(playlistId: 'pl1', name: 'Soul', addedAt: now),
      ],
      albums: [
        LikedAlbumModel(
          albumId: 'al1',
          name: 'Mahogany Soul',
          artistName: 'Angie Stone',
          addedAt: now,
        ),
      ],
      podcasts: [
        LikedPodcastModel(
          browseId: 'pod1',
          name: 'Interview',
          authorName: 'Angie Stone',
          addedAt: now,
        ),
      ],
      history: [
        HistoryModel(
          id: 1,
          videoId: 'hist1',
          title: 'No More Rain',
          artist: 'Angie Stone',
          playedAt: now,
          playCount: 2,
        ),
      ],
    );
  }

  group('filterLibraryCollections', () {
    test('blank query matches nothing', () {
      expect(filter('   ').isEmpty, isTrue);
    });

    test('matches title, artist, description, and author', () {
      final matches = filter('angie stone');

      expect(matches.songs.map((s) => s.videoId), ['song1']);
      expect(matches.artists.map((a) => a.artistId), ['artist1']);
      expect(matches.playlists.map((p) => p.id), [1]);
      expect(matches.likedPlaylists, isEmpty);
      expect(matches.albums.map((a) => a.albumId), ['al1']);
      expect(matches.podcasts.map((p) => p.browseId), ['pod1']);
      expect(matches.history.map((h) => h.videoId), ['hist1']);
    });

    test('isEmptyFor follows the search filter index', () {
      final matches = filter('soul');

      expect(matches.isEmptyFor(0), isFalse);
      expect(matches.isEmptyFor(1), isTrue);
      expect(matches.isEmptyFor(4), isFalse);
      expect(matches.isEmptyFor(6), isTrue);
    });
  });
}
