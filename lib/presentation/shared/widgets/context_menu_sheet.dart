import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/library_models.dart';
import 'context_menu/album_context_menu.dart';
import 'context_menu/artist_context_menu.dart';
import 'context_menu/context_menu_presenter.dart';
import 'context_menu/custom_playlist_context_menu.dart';
import 'context_menu/episode_context_menu.dart';
import 'context_menu/now_playing_context_menu.dart';
import 'context_menu/playlist_context_menu.dart';
import 'context_menu/podcast_context_menu.dart';
import 'context_menu/song_context_menu.dart';

/// Public entry point for entity context menus (dialog on wide, sheet otherwise).
class ContextMenuSheet {
  ContextMenuSheet._();

  static Future<void> showForSong(
    BuildContext context, {
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    List<ArtistBasic>? artists,
    String? artistsJson,
    String? playCount,
    int? viewCount,
    bool isExplicit = false,
    bool isPlayable = true,
  }) {
    return presentContextMenu(
      context,
      SongContextMenuSheet(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        albumName: albumName,
        artistId: artistId,
        albumId: albumId,
        artists: artists,
        artistsJson: artistsJson,
        playCount: playCount,
        viewCount: viewCount,
        isExplicit: isExplicit,
        isPlayable: isPlayable,
      ),
    );
  }

  static Future<void> showForArtist(
    BuildContext context, {
    required String artistId,
    required String name,
    String? thumbnailUrl,
    String? monthlyListeners,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToArtist = isOnEntityPage(context, 'artistId', artistId);
    return presentContextMenu(
      context,
      ArtistContextMenuSheet(
        artistId: artistId,
        name: name,
        thumbnailUrl: thumbnailUrl,
        monthlyListeners: monthlyListeners,
        hideGoToArtist: hideGoToArtist,
        omitActionIds: omitActionIds,
      ),
    );
  }

  static Future<void> showForAlbum(
    BuildContext context, {
    required String albumId,
    required String name,
    required String artist,
    String? artistId,
    String? thumbnailUrl,
    int? year,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToAlbum = isOnEntityPage(context, 'albumId', albumId);
    return presentContextMenu(
      context,
      AlbumContextMenuSheet(
        albumId: albumId,
        name: name,
        artist: artist,
        artistId: artistId,
        thumbnailUrl: thumbnailUrl,
        year: year,
        hideGoToAlbum: hideGoToAlbum,
        omitActionIds: omitActionIds,
      ),
    );
  }

  static Future<void> showForPodcast(
    BuildContext context, {
    required String browseId,
    required String name,
    String? author,
    String? thumbnailUrl,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToPodcast = isOnEntityPage(context, 'browseId', browseId);
    return presentContextMenu(
      context,
      PodcastContextMenuSheet(
        browseId: browseId,
        name: name,
        author: author,
        thumbnailUrl: thumbnailUrl,
        hideGoToPodcast: hideGoToPodcast,
        omitActionIds: omitActionIds,
      ),
    );
  }

  static Future<void> showForEpisode(
    BuildContext context, {
    required String videoId,
    required String name,
    String? podcastName,
    String? podcastBrowseId,
    String? thumbnailUrl,
    String? date,
    void Function(String podcastBrowseId)? onGoToPodcast,
  }) {
    final hideGoToPodcast =
        podcastBrowseId != null &&
        isOnEntityPage(context, 'browseId', podcastBrowseId);
    return presentContextMenu(
      context,
      EpisodeContextMenuSheet(
        videoId: videoId,
        name: name,
        podcastName: podcastName,
        podcastBrowseId: podcastBrowseId,
        thumbnailUrl: thumbnailUrl,
        date: date,
        onGoToPodcast: onGoToPodcast,
        hideGoToPodcast: hideGoToPodcast,
      ),
    );
  }

  static Future<void> showForPlaylist(
    BuildContext context, {
    required String playlistId,
    required String name,
    String? artist,
    String? thumbnailUrl,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToPlaylist = isOnEntityPage(context, 'playlistId', playlistId);
    return presentContextMenu(
      context,
      PlaylistContextMenuSheet(
        playlistId: playlistId,
        name: name,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        hideGoToPlaylist: hideGoToPlaylist,
        omitActionIds: omitActionIds,
      ),
    );
  }

  static Future<void> showForCustomPlaylist(
    BuildContext context, {
    required LocalPlaylistModel playlist,
    required VoidCallback onUpdated,
    bool hideGoToPlaylist = false,
    Set<String> omitActionIds = const {},
  }) {
    return presentContextMenu(
      context,
      CustomPlaylistContextMenuSheet(
        playlist: playlist,
        onUpdated: onUpdated,
        hideGoToPlaylist: hideGoToPlaylist,
        omitActionIds: omitActionIds,
      ),
    );
  }

  static Future<void> showForNowPlaying(
    BuildContext context, {
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    List<ArtistBasic>? artists,
    String? artistsJson,
    required void Function(String artistId) onGoToArtist,
    required void Function(String albumId) onGoToAlbum,
    bool isExplicit = false,
  }) {
    return presentContextMenu(
      context,
      NowPlayingContextMenuSheet(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        albumName: albumName,
        artistId: artistId,
        albumId: albumId,
        artists: artists,
        artistsJson: artistsJson,
        onGoToArtist: onGoToArtist,
        onGoToAlbum: onGoToAlbum,
        isExplicit: isExplicit,
      ),
    );
  }
}
