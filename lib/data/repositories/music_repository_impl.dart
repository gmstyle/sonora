import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../domain/models/media_quality.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/remote/ytmusic_datasource.dart';
import '../datasources/remote/stream_datasource.dart';

class MusicRepositoryImpl implements MusicRepository {
  final YtmusicDatasource _ytmusic;
  final StreamDatasource _stream;

  MusicRepositoryImpl(this._ytmusic, this._stream);

  @override
  Future<BrowseHomeResult> getHome({String? params, String? browseId}) =>
      _ytmusic.getHome(params: params, browseId: browseId);

  @override
  Future<List<SongDetailed>> searchSongs(String query) =>
      _ytmusic.searchSongs(query);

  @override
  Future<List<ArtistDetailed>> searchArtists(String query) =>
      _ytmusic.searchArtists(query);

  @override
  Future<List<AlbumDetailed>> searchAlbums(String query) =>
      _ytmusic.searchAlbums(query);

  @override
  Future<List<PlaylistDetailed>> searchPlaylists(String query) =>
      _ytmusic.searchPlaylists(query);

  @override
  Future<List<VideoDetailed>> searchVideos(String query) =>
      _ytmusic.searchVideos(query);

  @override
  Future<List<String>> getSearchSuggestions(String query) =>
      _ytmusic.getSearchSuggestions(query);

  @override
  Future<List<SearchResult>> search(String query) => _ytmusic.search(query);

  @override
  Future<SongFull> getSong(String videoId) => _ytmusic.getSong(videoId);

  @override
  Future<VideoFull> getVideo(String videoId) => _ytmusic.getVideo(videoId);

  @override
  Future<String?> getLyrics(String videoId) => _ytmusic.getLyrics(videoId);

  @override
  Future<TimedLyricsRes?> getTimedLyrics(String videoId) =>
      _ytmusic.getTimedLyrics(videoId);

  @override
  Future<List<UpNextsDetails>> getUpNexts(String videoId) =>
      _ytmusic.getUpNexts(videoId);

  @override
  Future<ArtistFull> getArtist(String artistId) => _ytmusic.getArtist(artistId);

  @override
  Future<List<SongDetailed>> getArtistSongs(String artistId) =>
      _ytmusic.getArtistSongs(artistId);

  @override
  Future<List<AlbumDetailed>> getArtistAlbums(String artistId) =>
      _ytmusic.getArtistAlbums(artistId);

  @override
  Future<List<AlbumDetailed>> getArtistSingles(String artistId) =>
      _ytmusic.getArtistSingles(artistId);

  @override
  Future<AlbumFull> getAlbum(String albumId) => _ytmusic.getAlbum(albumId);

  @override
  Future<PlaylistFull> getPlaylist(String playlistId) =>
      _ytmusic.getPlaylist(playlistId);

  @override
  Future<List<VideoDetailed>> getPlaylistVideos(String playlistId) =>
      _ytmusic.getPlaylistVideos(playlistId);

  @override
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? quality,
    bool preferVideo = false,
  }) => _stream.getStreamUrl(
    videoId,
    audioQuality: quality,
    preferVideo: preferVideo,
  );

  @override
  Future<WatchPlaylistResult> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    bool radio = false,
    bool shuffle = false,
  }) => _ytmusic.getWatchPlaylist(
    videoId: videoId,
    playlistId: playlistId,
    radio: radio,
    shuffle: shuffle,
  );

  @override
  Future<List<RelatedSection>> getSongRelated(String browseId) =>
      _ytmusic.getSongRelated(browseId);

  @override
  Future<List<VideoDetailed>> getArtistVideos(String artistId) =>
      _ytmusic.getArtistVideos(artistId);

  @override
  Future<ChartsResult> getCharts({String country = 'ZZ'}) =>
      _ytmusic.getCharts(country: country);

  @override
  Future<MoodCategoriesResult> getMoodCategories() =>
      _ytmusic.getMoodCategories();

  @override
  Future<List<PlaylistDetailed>> getMoodPlaylists(String params) =>
      _ytmusic.getMoodPlaylists(params);

  @override
  Future<NewReleasesResult> getNewReleases() => _ytmusic.getNewReleases();

  @override
  Future<String?> getAlbumBrowseId(String audioPlaylistId) =>
      _ytmusic.getAlbumBrowseId(audioPlaylistId);

  @override
  Future<List<PodcastDetailed>> searchPodcasts(
    String query, {
    int limit = 20,
  }) => _ytmusic.searchPodcasts(query, limit: limit);

  @override
  Future<List<EpisodeDetailed>> searchEpisodes(
    String query, {
    int limit = 20,
  }) => _ytmusic.searchEpisodes(query, limit: limit);

  @override
  Future<List<ProfileDetailed>> searchProfiles(
    String query, {
    int limit = 20,
  }) => _ytmusic.searchProfiles(query, limit: limit);

  @override
  Future<UserFull> getUser(String channelId) => _ytmusic.getUser(channelId);

  @override
  Future<List<PlaylistDetailed>> getUserPlaylists(
    String channelId,
    String params,
  ) => _ytmusic.getUserPlaylists(channelId, params);

  @override
  Future<List<VideoDetailed>> getUserVideos(
    String channelId,
    String params,
  ) => _ytmusic.getUserVideos(channelId, params);
}
