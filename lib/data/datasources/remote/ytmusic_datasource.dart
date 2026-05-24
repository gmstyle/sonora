import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

class YtmusicDatasource {
  YTMusic get client => YTMusic();
  String _gl = 'US';
  String _hl = 'en';

  Future<void> initialize({String? gl, String? hl}) async {
    _gl = gl ?? _gl;
    _hl = hl ?? _hl;
    await client.initialize(gl: _gl, hl: _hl);
  }

  bool get isInitialized => client.hasInitialized;

  Future<void> reinitialize({required String gl, required String hl}) async {
    _gl = gl;
    _hl = hl;
    client.hasInitialized = false;
    await client.initialize(gl: _gl, hl: _hl);
  }

  Future<List<HomeSection>> getHomeSections() => client.getHomeSections();

  Future<List<SongDetailed>> searchSongs(String query) =>
      client.searchSongs(query);

  Future<List<ArtistDetailed>> searchArtists(String query) =>
      client.searchArtists(query);

  Future<List<AlbumDetailed>> searchAlbums(String query) =>
      client.searchAlbums(query);

  Future<List<PlaylistDetailed>> searchPlaylists(String query) =>
      client.searchPlaylists(query);

  Future<List<VideoDetailed>> searchVideos(String query) =>
      client.searchVideos(query);

  Future<List<String>> getSearchSuggestions(String query) =>
      client.getSearchSuggestions(query);

  Future<List<SearchResult>> search(String query) => client.search(query);

  Future<SongFull> getSong(String videoId) => client.getSong(videoId);

  Future<VideoFull> getVideo(String videoId) => client.getVideo(videoId);

  Future<String?> getLyrics(String videoId) => client.getLyrics(videoId);

  Future<TimedLyricsRes?> getTimedLyrics(String videoId) =>
      client.getTimedLyrics(videoId);

  Future<List<UpNextsDetails>> getUpNexts(String videoId) =>
      client.getUpNexts(videoId);

  Future<ArtistFull> getArtist(String artistId) => client.getArtist(artistId);

  Future<List<SongDetailed>> getArtistSongs(String artistId) =>
      client.getArtistSongs(artistId);

  Future<List<AlbumDetailed>> getArtistAlbums(String artistId) =>
      client.getArtistAlbums(artistId);

  Future<List<AlbumDetailed>> getArtistSingles(String artistId) =>
      client.getArtistSingles(artistId);

  Future<AlbumFull> getAlbum(String albumId) => client.getAlbum(albumId);

  Future<PlaylistFull> getPlaylist(String playlistId) =>
      client.getPlaylist(playlistId);

  Future<List<VideoDetailed>> getPlaylistVideos(String playlistId) =>
      client.getPlaylistVideos(playlistId);
}
