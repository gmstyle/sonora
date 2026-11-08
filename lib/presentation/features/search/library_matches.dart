import '../../../domain/models/library_models.dart';

/// How many rows each library group shows before "Show more".
const kLibraryMatchPreviewLimit = 4;

/// Local library rows that match a search query.
class LibraryMatches {
  final List<LikedSongModel> songs;
  final List<FollowedArtistModel> artists;
  final List<LocalPlaylistModel> playlists;
  final List<LikedPlaylistModel> likedPlaylists;
  final List<LikedAlbumModel> albums;
  final List<LikedPodcastModel> podcasts;
  final List<HistoryModel> history;

  const LibraryMatches({
    this.songs = const [],
    this.artists = const [],
    this.playlists = const [],
    this.likedPlaylists = const [],
    this.albums = const [],
    this.podcasts = const [],
    this.history = const [],
  });

  static const empty = LibraryMatches();

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty &&
      likedPlaylists.isEmpty &&
      albums.isEmpty &&
      podcasts.isEmpty &&
      history.isEmpty;

  /// Search filter index: 0 all, 1 songs, 2 artists, 3 albums, 4 playlists,
  /// 5 podcasts. Episodes and profiles have no library collection.
  bool isEmptyFor(int filter) {
    return switch (filter) {
      1 => songs.isEmpty,
      2 => artists.isEmpty,
      3 => albums.isEmpty,
      4 => playlists.isEmpty && likedPlaylists.isEmpty,
      5 => podcasts.isEmpty,
      6 || 7 => true,
      _ => isEmpty,
    };
  }
}

bool _contains(String? value, String query) =>
    value != null && value.toLowerCase().contains(query);

/// Case-insensitive substring match across the same fields the library
/// search used: title and artist, plus playlist description and podcast author.
LibraryMatches filterLibraryCollections({
  required String query,
  required List<LikedSongModel> songs,
  required List<FollowedArtistModel> artists,
  required List<LocalPlaylistModel> playlists,
  required List<LikedPlaylistModel> likedPlaylists,
  required List<LikedAlbumModel> albums,
  required List<LikedPodcastModel> podcasts,
  required List<HistoryModel> history,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return LibraryMatches.empty;

  return LibraryMatches(
    songs: [
      for (final song in songs)
        if (_contains(song.title, needle) || _contains(song.artist, needle))
          song,
    ],
    artists: [
      for (final artist in artists)
        if (_contains(artist.name, needle)) artist,
    ],
    playlists: [
      for (final playlist in playlists)
        if (_contains(playlist.name, needle) ||
            _contains(playlist.description, needle))
          playlist,
    ],
    likedPlaylists: [
      for (final playlist in likedPlaylists)
        if (_contains(playlist.name, needle)) playlist,
    ],
    albums: [
      for (final album in albums)
        if (_contains(album.name, needle) ||
            _contains(album.artistName, needle))
          album,
    ],
    podcasts: [
      for (final podcast in podcasts)
        if (_contains(podcast.name, needle) ||
            _contains(podcast.authorName, needle))
          podcast,
    ],
    history: [
      for (final entry in history)
        if (_contains(entry.title, needle) || _contains(entry.artist, needle))
          entry,
    ],
  );
}
