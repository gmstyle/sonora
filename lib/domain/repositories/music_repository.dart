import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../models/media_quality.dart';

abstract class MusicRepository {
  Future<BrowseHomeResult> getHome({String? params, String? browseId});
  Future<List<SongDetailed>> searchSongs(String query);
  Future<List<ArtistDetailed>> searchArtists(String query);
  Future<List<AlbumDetailed>> searchAlbums(String query);
  Future<List<PlaylistDetailed>> searchPlaylists(String query);
  Future<List<VideoDetailed>> searchVideos(String query);
  Future<List<String>> getSearchSuggestions(String query);
  Future<List<SearchResult>> search(String query);
  Future<SongFull> getSong(String videoId);
  Future<VideoFull> getVideo(String videoId);
  Future<String?> getLyrics(String videoId);
  Future<TimedLyricsRes?> getTimedLyrics(String videoId);
  Future<List<UpNextsDetails>> getUpNexts(String videoId);
  Future<ArtistFull> getArtist(String artistId);
  Future<List<SongDetailed>> getArtistSongs(String artistId);
  Future<List<AlbumDetailed>> getArtistAlbums(String artistId);
  Future<List<AlbumDetailed>> getArtistSingles(String artistId);
  Future<AlbumFull> getAlbum(String albumId);
  Future<PlaylistFull> getPlaylist(String playlistId);
  Future<List<VideoDetailed>> getPlaylistVideos(String playlistId);
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? quality,
    bool preferVideo = false,
  });

  Future<WatchPlaylistResult> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    bool radio = false,
    bool shuffle = false,
  });
  Future<List<RelatedSection>> getSongRelated(String browseId);
  Future<List<VideoDetailed>> getArtistVideos(String artistId);
  Future<ChartsResult> getCharts({String country = 'ZZ'});
  Future<MoodCategoriesResult> getMoodCategories();
  Future<List<PlaylistDetailed>> getMoodPlaylists(String params);
  Future<NewReleasesResult> getNewReleases();
  Future<String?> getAlbumBrowseId(String audioPlaylistId);
  Future<List<PodcastDetailed>> searchPodcasts(String query, {int limit = 20});
  Future<List<EpisodeDetailed>> searchEpisodes(String query, {int limit = 20});
  Future<List<ProfileDetailed>> searchProfiles(String query, {int limit = 20});
  Future<UserFull> getUser(String channelId);
  Future<List<PlaylistDetailed>> getUserPlaylists(
    String channelId,
    String params,
  );
  Future<List<VideoDetailed>> getUserVideos(String channelId, String params);
}
