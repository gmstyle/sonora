import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/ask_chat_models.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import 'aa_content_styles.dart';
import 'aa_media_id.dart';

/// Maps Sonora domain models and YTMusic entities into Android Auto [MediaItem]s.
abstract final class AaContentMapper {
  static List<MediaItem> homeContentToMediaItems(
    dynamic content, {
    String? groupTitle,
    int playableStyle = AaContentStyles.styleList,
    int browsableStyle = AaContentStyles.styleGrid,
    String? contextKind,
    String? contextId,
    int? contextIndex,
  }) {
    if (content is SongDetailed) {
      if (!content.isPlayable) return const [];
      return [
        songToMediaItem(
          content,
          groupTitle: groupTitle,
          playableStyle: playableStyle,
          contextKind: contextKind,
          contextId: contextId,
          contextIndex: contextIndex,
        ),
      ];
    }
    if (content is VideoDetailed) {
      if (!content.isPlayable) return const [];
      return [
        videoToMediaItem(
          content,
          groupTitle: groupTitle,
          playableStyle: playableStyle,
          contextKind: contextKind,
          contextId: contextId,
          contextIndex: contextIndex,
        ),
      ];
    }
    if (content is AlbumDetailed) {
      return [
        albumToBrowseItem(
          content,
          groupTitle: groupTitle,
          browsableStyle: browsableStyle,
        ),
      ];
    }
    if (content is PlaylistDetailed) {
      return [
        playlistToBrowseItem(
          content,
          groupTitle: groupTitle,
          browsableStyle: browsableStyle,
        ),
      ];
    }
    if (content is ArtistDetailed) {
      return [
        artistToBrowseItem(
          content,
          groupTitle: groupTitle,
          browsableStyle: browsableStyle,
        ),
      ];
    }
    if (content is PodcastDetailed) {
      if (content.browseId.isEmpty) return const [];
      return [
        podcastToBrowseItem(
          content,
          groupTitle: groupTitle,
          browsableStyle: browsableStyle,
        ),
      ];
    }
    if (content is EpisodeDetailed) {
      final item = episodeToMediaItem(
        content,
        groupTitle: groupTitle,
        playableStyle: playableStyle,
      );
      return item != null ? [item] : const [];
    }
    return const [];
  }

  static MediaItem songToMediaItem(
    SongDetailed s, {
    String? groupTitle,
    int playableStyle = AaContentStyles.styleList,
    String? contextKind,
    String? contextId,
    int? contextIndex,
  }) {
    final track = QueueTrack(
      videoId: s.videoId,
      needsUrl: true,
      isVideo: s.type == 'VIDEO',
      isExplicit: s.isExplicit,
      artistId: primaryArtistId(s.artists),
      albumId: s.album?.albumId,
      artistsJson: encodeArtistsJson(s.artists),
      title: s.name,
      artist: displayArtists(s.artists),
      album: s.album?.name,
      duration: Duration(seconds: s.duration ?? 0),
      artUri: s.thumbnails.isNotEmpty
          ? Uri.tryParse(s.thumbnails.last.url)
          : null,
    );
    final item = track.toFreshMediaItem(
      additionalExtras: AaContentStyles.styleExtras(
        playable: playableStyle,
        groupTitle: groupTitle,
        isExplicit: s.isExplicit,
      ),
    );
    if (contextKind != null && contextId != null && contextIndex != null) {
      return item.copyWith(
        id: AaMediaId.playTrack(
          contextKind: contextKind,
          contextId: contextId,
          index: contextIndex,
          videoId: s.videoId,
        ),
      );
    }
    return item;
  }

  static MediaItem videoToMediaItem(
    VideoDetailed v, {
    String? groupTitle,
    int playableStyle = AaContentStyles.styleList,
    String? contextKind,
    String? contextId,
    int? contextIndex,
  }) {
    final track = QueueTrack(
      videoId: v.videoId,
      needsUrl: true,
      isVideo: true,
      isExplicit: v.isExplicit,
      artistId: primaryArtistId(v.artists),
      artistsJson: encodeArtistsJson(v.artists),
      title: v.name,
      artist: displayArtists(v.artists),
      duration: Duration(seconds: v.duration ?? 0),
      artUri: v.thumbnails.isNotEmpty
          ? Uri.tryParse(v.thumbnails.last.url)
          : null,
    );
    final item = track.toFreshMediaItem(
      additionalExtras: AaContentStyles.styleExtras(
        playable: playableStyle,
        groupTitle: groupTitle,
        isExplicit: v.isExplicit,
      ),
    );
    if (contextKind != null && contextId != null && contextIndex != null) {
      return item.copyWith(
        id: AaMediaId.playTrack(
          contextKind: contextKind,
          contextId: contextId,
          index: contextIndex,
          videoId: v.videoId,
        ),
      );
    }
    return item;
  }

  static MediaItem albumToBrowseItem(
    AlbumDetailed album, {
    String? groupTitle,
    int browsableStyle = AaContentStyles.styleGrid,
  }) {
    return MediaItem(
      id: AaMediaId.album(album.albumId),
      title: album.name,
      artist: displayArtists(album.artists),
      artUri: album.thumbnails.isNotEmpty
          ? Uri.tryParse(album.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_albums'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: browsableStyle,
        playable: AaContentStyles.styleList,
        groupTitle: groupTitle,
      ),
    );
  }

  static MediaItem playlistToBrowseItem(
    PlaylistDetailed playlist, {
    String? groupTitle,
    int browsableStyle = AaContentStyles.styleGrid,
  }) {
    return MediaItem(
      id: AaMediaId.remotePlaylist(playlist.playlistId),
      title: playlist.name,
      artist: displayArtists(playlist.artists),
      artUri: playlist.thumbnails.isNotEmpty
          ? Uri.tryParse(playlist.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_playlist'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: browsableStyle,
        playable: AaContentStyles.styleList,
        groupTitle: groupTitle,
      ),
    );
  }

  static MediaItem artistToBrowseItem(
    ArtistDetailed artist, {
    String? groupTitle,
    int browsableStyle = AaContentStyles.styleGrid,
  }) {
    return MediaItem(
      id: AaMediaId.artist(artist.artistId),
      title: artist.name,
      artUri: artist.thumbnails.isNotEmpty
          ? Uri.tryParse(artist.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_artists'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: browsableStyle,
        playable: AaContentStyles.styleList,
        groupTitle: groupTitle,
      ),
    );
  }

  static MediaItem podcastToBrowseItem(
    PodcastDetailed podcast, {
    String? groupTitle,
    int browsableStyle = AaContentStyles.styleGrid,
  }) {
    return MediaItem(
      id: AaMediaId.podcast(podcast.browseId),
      title: podcast.name,
      artist: podcast.author,
      artUri: podcast.thumbnails.isNotEmpty
          ? Uri.tryParse(podcast.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_podcasts'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: browsableStyle,
        playable: AaContentStyles.styleList,
        groupTitle: groupTitle,
      ),
    );
  }

  static MediaItem? episodeToMediaItem(
    EpisodeDetailed episode, {
    String? groupTitle,
    int playableStyle = AaContentStyles.styleList,
  }) {
    if (episode.videoId.isEmpty) return null;
    final track = QueueTrack(
      videoId: episode.videoId,
      needsUrl: true,
      contentType: 'episode',
      podcastBrowseId: episode.podcastId,
      title: episode.name,
      artist: episode.podcastName ?? '',
      album: episode.podcastName,
      publishDate: episode.date,
      artUri: episode.thumbnails.isNotEmpty
          ? Uri.tryParse(episode.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_podcasts'),
    );
    return track.toFreshMediaItem(
      additionalExtras: AaContentStyles.styleExtras(
        playable: playableStyle,
        groupTitle: groupTitle,
      ),
    );
  }

  static MediaItem historyToMediaItem(
    HistoryModel h, {
    required int index,
    String contextKind = AaMediaId.ctxHistory,
    String contextId = 'all',
    String? groupTitle,
  }) {
    final track = QueueTrack(
      videoId: h.videoId,
      needsUrl: true,
      isVideo: h.isVideo,
      isExplicit: h.isExplicit,
      contentType: h.contentType,
      podcastBrowseId: h.podcastBrowseId,
      title: h.title,
      artist: h.artist,
      duration: h.duration != null ? Duration(seconds: h.duration!) : null,
      artUri: h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
    );
    return track
        .toFreshMediaItem(
          additionalExtras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
            groupTitle: groupTitle,
            isExplicit: h.isExplicit,
          ),
        )
        .copyWith(
          id: AaMediaId.playTrack(
            contextKind: contextKind,
            contextId: contextId,
            index: index,
            videoId: h.videoId,
          ),
        );
  }

  static MediaItem likedSongToMediaItem(
    LikedSongModel s, {
    required int index,
    String contextKind = AaMediaId.ctxFavorites,
    String contextId = 'all',
    String? groupTitle,
  }) {
    final track = QueueTrack(
      videoId: s.videoId,
      needsUrl: true,
      isVideo: s.isVideo,
      isExplicit: s.isExplicit,
      artistId: s.artistId,
      albumId: s.albumId,
      artistsJson: s.artistsJson,
      title: s.title,
      artist: s.artist,
      duration: s.duration != null ? Duration(seconds: s.duration!) : null,
      artUri: s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
    );
    return track
        .toFreshMediaItem(
          additionalExtras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
            groupTitle: groupTitle,
            isExplicit: s.isExplicit,
          ),
        )
        .copyWith(
          id: AaMediaId.playTrack(
            contextKind: contextKind,
            contextId: contextId,
            index: index,
            videoId: s.videoId,
          ),
        );
  }

  static MediaItem likedEpisodeToMediaItem(
    LikedEpisodeModel ep, {
    required int index,
    String contextKind = AaMediaId.ctxSavedEpisodes,
    String contextId = 'all',
    String? groupTitle,
  }) {
    final track = QueueTrack(
      videoId: ep.videoId,
      needsUrl: true,
      isVideo: false,
      contentType: 'episode',
      podcastBrowseId: ep.podcastBrowseId,
      title: ep.name,
      artist: ep.podcastName ?? '',
      album: ep.podcastName,
      publishDate: ep.date,
      duration: ep.durationSec != null
          ? Duration(seconds: ep.durationSec!)
          : null,
      artUri: ep.thumbnailUrl != null
          ? Uri.tryParse(ep.thumbnailUrl!)
          : AaContentStyles.drawableUri('cover_saved_episodes'),
    );
    return track
        .toFreshMediaItem(
          additionalExtras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
            groupTitle: groupTitle,
          ),
        )
        .copyWith(
          id: AaMediaId.playTrack(
            contextKind: contextKind,
            contextId: contextId,
            index: index,
            videoId: ep.videoId,
          ),
        );
  }

  static MediaItem downloadToMediaItem(
    DownloadModel d, {
    required int index,
    required String groupKey,
    String? groupTitle,
  }) {
    final isPodcast = d.collectionType == 'podcast';
    final track = QueueTrack(
      videoId: d.videoId,
      needsUrl: true,
      isVideo: d.isVideo,
      isExplicit: d.isExplicit,
      artistsJson: d.artistsJson,
      contentType: isPodcast ? 'episode' : 'song',
      podcastBrowseId: isPodcast ? d.collectionId : null,
      title: d.title,
      artist: d.artist,
      album: d.collectionName,
      artUri: d.thumbnailUrl != null ? Uri.tryParse(d.thumbnailUrl!) : null,
    );
    return track
        .toFreshMediaItem(
          additionalExtras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
            groupTitle: groupTitle,
            isExplicit: d.isExplicit,
          ),
        )
        .copyWith(
          id: AaMediaId.playTrack(
            contextKind: AaMediaId.ctxDownloadGroup,
            contextId: groupKey,
            index: index,
            videoId: d.videoId,
          ),
        );
  }

  static MediaItem askTrackToMediaItem(
    AskTrackRef t, {
    required String contextId,
    required int index,
    String? groupTitle,
  }) {
    final track = QueueTrack(
      videoId: t.videoId,
      needsUrl: true,
      isVideo: t.isVideo,
      isExplicit: t.isExplicit,
      artistId: t.artistId,
      albumId: t.albumId,
      artistsJson: t.artistsJson,
      title: t.title,
      artist: t.artist,
      album: t.albumName,
      duration: t.durationSec != null
          ? Duration(seconds: t.durationSec!)
          : null,
      artUri: t.thumbnailUrl != null ? Uri.tryParse(t.thumbnailUrl!) : null,
    );
    return track
        .toFreshMediaItem(
          additionalExtras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
            groupTitle: groupTitle,
            isExplicit: t.isExplicit,
          ),
        )
        .copyWith(
          id: AaMediaId.playTrack(
            contextKind: AaMediaId.ctxAskMix,
            contextId: contextId,
            index: index,
            videoId: t.videoId,
          ),
        );
  }
}
