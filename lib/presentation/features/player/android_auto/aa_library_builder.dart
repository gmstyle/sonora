import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../core/utils/playable_tracks.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../l10n/app_localizations.dart';
import 'aa_content_mapper.dart';
import 'aa_content_styles.dart';
import 'aa_home_builder.dart';
import 'aa_media_id.dart';

/// Builds the Android Auto Library tree (Favorites, Playlists, Albums, Artists,
/// Podcasts + Saved Episodes, History, Smart Mixes, and Ask Mixes).
class AaLibraryBuilder {
  final LibraryRepository _libraryRepo;
  final MusicRepository _musicRepo;
  final SharedPreferences? _prefs;
  final AaHomeBuilder _homeBuilder;

  static const String _kSortTypeKey = 'librarySortType';

  AaLibraryBuilder({
    required this._libraryRepo,
    required this._musicRepo,
    required this._prefs,
    required this._homeBuilder,
  });

  int get _sortIndex => _prefs?.getInt(_kSortTypeKey) ?? 2;

  List<T> _sortByPref<T>(
    List<T> items, {
    required String Function(T) nameOf,
    required DateTime Function(T) dateOf,
  }) {
    final list = List<T>.of(items);
    switch (_sortIndex) {
      case 0:
        list.sort(
          (a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()),
        );
      case 1:
        list.sort(
          (a, b) => nameOf(b).toLowerCase().compareTo(nameOf(a).toLowerCase()),
        );
      case 3:
        list.sort((a, b) => dateOf(a).compareTo(dateOf(b)));
      case 2:
      default:
        list.sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    }
    return list;
  }

  List<MediaItem> buildLibraryRoot(AppLocalizations l10n) {
    return [
      MediaItem(
        id: AaMediaId.favorites,
        title: l10n.favorites,
        displaySubtitle: l10n.aaYourMusicSubtitle,
        artUri: AaContentStyles.drawableUri('cover_favorites'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.playlists,
        title: l10n.playlists,
        displaySubtitle: l10n.myPlaylists,
        artUri: AaContentStyles.drawableUri('cover_playlist'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.artists,
        title: l10n.artists,
        displaySubtitle: l10n.yourArtists,
        artUri: AaContentStyles.drawableUri('cover_artists'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.albums,
        title: l10n.albums,
        displaySubtitle: l10n.likedAlbumsHome,
        artUri: AaContentStyles.drawableUri('cover_albums'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.podcasts,
        title: l10n.aaPodcastsAndEpisodes,
        displaySubtitle: l10n.aaSubscribedPodcasts,
        artUri: AaContentStyles.drawableUri('cover_podcasts'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.history,
        title: l10n.history,
        displaySubtitle: l10n.recentlyPlayed,
        artUri: AaContentStyles.drawableUri('cover_history'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.mixes,
        title: l10n.mixes,
        displaySubtitle: l10n.aaPulseAndMixes,
        artUri: AaContentStyles.drawableUri('cover_most_played'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
        ),
      ),
    ];
  }

  Future<List<LikedSongModel>> getSortedFavorites() async {
    final songs = await _libraryRepo.getAllLikedSongs();
    return _sortByPref(songs, nameOf: (s) => s.title, dateOf: (s) => s.addedAt);
  }

  Future<List<MediaItem>> buildFavoritesChildren(AppLocalizations l10n) async {
    final songs = await getSortedFavorites();
    if (songs.isEmpty) return const [];
    return [
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, 'favorites', 'all'),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, 'favorites', 'all'),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      for (var i = 0; i < songs.length; i++)
        AaContentMapper.likedSongToMediaItem(songs[i], index: i),
    ];
  }

  Future<List<MediaItem>> buildPlaylistFolders(AppLocalizations l10n) async {
    final (localRaw, likedRaw) = await (
      _libraryRepo.getAllPlaylists(),
      _libraryRepo.getAllLikedPlaylists(),
    ).wait;

    final local = _sortByPref(
      localRaw,
      nameOf: (p) => p.name,
      dateOf: (p) => p.createdAt,
    );
    final liked = _sortByPref(
      likedRaw,
      nameOf: (p) => p.name,
      dateOf: (p) => p.addedAt,
    );

    final entryLists = await Future.wait(
      local.map((p) => _libraryRepo.getPlaylistEntries(p.id)),
    );

    final items = <MediaItem>[];
    for (var i = 0; i < local.length; i++) {
      final p = local[i];
      final entries = entryLists[i];
      final countLabel = l10n.songCount(entries.length);
      final sourceLabel = switch (p.isLinked ? p.sourceKind : null) {
        'spotify' => '${l10n.aaLinkedSourceSpotify} · $countLabel',
        'youtube' => '${l10n.aaLinkedSourceYoutube} · $countLabel',
        _ => '${l10n.aaLocalPlaylistSubtitle} · $countLabel',
      };
      String? thumb;
      for (final e in entries) {
        if (e.thumbnailUrl != null && e.thumbnailUrl!.isNotEmpty) {
          thumb = e.thumbnailUrl;
          break;
        }
      }
      items.add(
        MediaItem(
          id: AaMediaId.localPlaylist(p.id),
          title: p.name,
          displaySubtitle: sourceLabel,
          artUri: thumb != null
              ? Uri.tryParse(thumb)
              : AaContentStyles.drawableUri('cover_playlist'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleGrid,
            playable: AaContentStyles.styleList,
            groupTitle: l10n.myPlaylists,
          ),
        ),
      );
    }

    for (final p in liked) {
      items.add(
        MediaItem(
          id: AaMediaId.remotePlaylist(p.playlistId),
          title: p.name,
          displaySubtitle: p.videoCount != null
              ? '${l10n.aaLikedPlaylistSubtitle} · ${l10n.songCount(p.videoCount!)}'
              : l10n.aaLikedPlaylistSubtitle,
          artUri: p.thumbnailUrl != null
              ? Uri.tryParse(p.thumbnailUrl!)
              : AaContentStyles.drawableUri('cover_playlist'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleGrid,
            playable: AaContentStyles.styleList,
            groupTitle: l10n.likedPlaylists,
          ),
        ),
      );
    }

    return items;
  }

  Future<List<MediaItem>> buildLocalPlaylistChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final playlistId = int.tryParse(
      parentMediaId.substring(AaMediaId.localPlaylistPrefix.length),
    );
    if (playlistId == null) return const [];

    final (entries, allLiked) = await (
      _libraryRepo.getPlaylistEntries(playlistId),
      _libraryRepo.getAllLikedSongs(),
    ).wait;
    final likedByVideoId = {for (final s in allLiked) s.videoId: s};

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actPlay,
          AaMediaId.ctxLocalPlaylist,
          '$playlistId',
        ),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actShuffle,
          AaMediaId.ctxLocalPlaylist,
          '$playlistId',
        ),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final liked = likedByVideoId[entry.videoId];
      final durationSec = liked?.duration ?? entry.duration;
      final thumb = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      final isExplicit = liked?.isExplicit ?? entry.isExplicit;
      final track = QueueTrack(
        videoId: entry.videoId,
        needsUrl: true,
        isVideo: liked?.isVideo ?? entry.isVideo,
        isExplicit: isExplicit,
        artistId: liked?.artistId,
        artistsJson: liked?.artistsJson ?? entry.artistsJson,
        title: liked?.title ?? entry.title ?? entry.videoId,
        artist: liked?.artist ?? entry.artist ?? '',
        duration: durationSec != null ? Duration(seconds: durationSec) : null,
        artUri: thumb != null ? Uri.tryParse(thumb) : null,
      );
      items.add(
        track
            .toFreshMediaItem(
              additionalExtras: AaContentStyles.styleExtras(
                playable: AaContentStyles.styleList,
                isExplicit: isExplicit,
              ),
            )
            .copyWith(
              id: AaMediaId.playTrack(
                contextKind: AaMediaId.ctxLocalPlaylist,
                contextId: '$playlistId',
                index: i,
                videoId: entry.videoId,
              ),
            ),
      );
    }

    return items;
  }

  Future<List<MediaItem>> buildArtistFolders(AppLocalizations l10n) async {
    final raw = await _libraryRepo.getAllFollowedArtists();
    final artists = _sortByPref(
      raw,
      nameOf: (a) => a.name,
      dateOf: (a) => a.addedAt,
    );
    return artists
        .map(
          (a) => MediaItem(
            id: AaMediaId.artist(a.artistId),
            title: a.name,
            artUri: a.thumbnailUrl != null
                ? Uri.tryParse(a.thumbnailUrl!)
                : AaContentStyles.drawableUri('cover_artists'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleGrid,
              playable: AaContentStyles.styleList,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MediaItem>> buildArtistChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final artistId = parentMediaId.substring(AaMediaId.artistPrefix.length);
    final (artistInfo, followed) = await (
      _musicRepo.getArtist(artistId),
      _libraryRepo.getFollowedArtist(artistId),
    ).wait;

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxArtist, artistId),
        title: l10n.playTopSongs,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actShuffle,
          AaMediaId.ctxArtist,
          artistId,
        ),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actRadio, AaMediaId.ctxArtist, artistId),
        title: l10n.artistRadio,
        artUri: AaContentStyles.drawableUri('ic_radio'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actAffinity,
          AaMediaId.ctxArtist,
          artistId,
        ),
        title: followed != null ? l10n.following : l10n.follow,
        artUri: AaContentStyles.drawableUri('ic_artist'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    final songs = playableSongs(artistInfo.topSongs);
    for (var i = 0; i < songs.length; i++) {
      items.add(
        AaContentMapper.songToMediaItem(
          songs[i],
          groupTitle: l10n.popular,
          contextKind: AaMediaId.ctxArtist,
          contextId: artistId,
          contextIndex: i,
        ),
      );
    }

    for (final album in artistInfo.topAlbums) {
      items.add(
        AaContentMapper.albumToBrowseItem(album, groupTitle: l10n.albums),
      );
    }
    for (final single in artistInfo.topSingles) {
      items.add(
        AaContentMapper.albumToBrowseItem(single, groupTitle: l10n.singles),
      );
    }
    for (final playlist in artistInfo.featuredOn) {
      items.add(
        AaContentMapper.playlistToBrowseItem(
          playlist,
          groupTitle: l10n.featuredOn,
        ),
      );
    }
    for (final related in artistInfo.similarArtists) {
      items.add(
        AaContentMapper.artistToBrowseItem(
          related,
          groupTitle: l10n.similarArtists,
        ),
      );
    }

    return items;
  }

  Future<List<MediaItem>> buildLikedAlbumFolders() async {
    final raw = await _libraryRepo.getAllLikedAlbums();
    final albums = _sortByPref(
      raw,
      nameOf: (a) => a.name,
      dateOf: (a) => a.addedAt,
    );
    return albums
        .map(
          (a) => MediaItem(
            id: AaMediaId.album(a.albumId),
            title: a.name,
            artist: a.artistName,
            artUri: a.thumbnailUrl != null
                ? Uri.tryParse(a.thumbnailUrl!)
                : AaContentStyles.drawableUri('cover_albums'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleGrid,
              playable: AaContentStyles.styleList,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MediaItem>> buildPodcastRoot(AppLocalizations l10n) async {
    final (podcastsRaw, savedEpisodes) = await (
      _libraryRepo.getAllLikedPodcasts(),
      _libraryRepo.getAllLikedEpisodes(),
    ).wait;

    final podcasts = _sortByPref(
      podcastsRaw,
      nameOf: (p) => p.name,
      dateOf: (p) => p.addedAt,
    );

    final items = <MediaItem>[];
    if (savedEpisodes.isNotEmpty) {
      items.add(
        MediaItem(
          id: AaMediaId.savedEpisodes,
          title: l10n.aaSavedEpisodes,
          displaySubtitle:
              '${l10n.aaSavedEpisodesSubtitle} · ${savedEpisodes.length}',
          artUri: AaContentStyles.drawableUri('cover_saved_episodes'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleList,
            playable: AaContentStyles.styleList,
            groupTitle: l10n.episodes,
          ),
        ),
      );
    }

    for (final p in podcasts) {
      items.add(
        MediaItem(
          id: AaMediaId.podcast(p.browseId),
          title: p.name,
          artist: p.authorName,
          artUri: p.thumbnailUrl != null
              ? Uri.tryParse(p.thumbnailUrl!)
              : AaContentStyles.drawableUri('cover_podcasts'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleGrid,
            playable: AaContentStyles.styleList,
            groupTitle: l10n.podcasts,
          ),
        ),
      );
    }
    return items;
  }

  Future<List<LikedEpisodeModel>> getSortedSavedEpisodes() async {
    final episodes = await _libraryRepo.getAllLikedEpisodes();
    return _sortByPref(
      episodes,
      nameOf: (e) => e.name,
      dateOf: (e) => e.addedAt,
    );
  }

  Future<List<MediaItem>> buildSavedEpisodesChildren(
    AppLocalizations l10n,
  ) async {
    final episodes = await getSortedSavedEpisodes();
    if (episodes.isEmpty) return const [];
    return [
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actPlay,
          AaMediaId.ctxSavedEpisodes,
          'all',
        ),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actShuffle,
          AaMediaId.ctxSavedEpisodes,
          'all',
        ),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      for (var i = 0; i < episodes.length; i++)
        AaContentMapper.likedEpisodeToMediaItem(episodes[i], index: i),
    ];
  }

  Future<List<MediaItem>> buildPodcastChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final browseId = parentMediaId.substring(AaMediaId.podcastPrefix.length);
    final (podcast, liked) = await (
      _musicRepo.getPodcast(browseId, limit: 100),
      _libraryRepo.getLikedPodcast(browseId),
    ).wait;

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxPodcast, browseId),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actShuffle,
          AaMediaId.ctxPodcast,
          browseId,
        ),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actAffinity,
          AaMediaId.ctxPodcast,
          browseId,
        ),
        title: liked != null ? l10n.subscribed : l10n.subscribe,
        artUri: AaContentStyles.drawableUri(
          liked != null ? 'ic_bookmark' : 'ic_bookmark_border',
        ),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    final authorName = podcast.author?.name ?? podcast.name;
    final playable = podcast.episodes
        .where((e) => e.videoId.isNotEmpty)
        .take(100)
        .toList(growable: false);
    for (var i = 0; i < playable.length; i++) {
      final e = playable[i];
      final seconds = Parser.parseDuration(e.duration);
      final track = QueueTrack(
        videoId: e.videoId,
        needsUrl: true,
        isVideo: false,
        contentType: 'episode',
        podcastBrowseId: browseId,
        title: e.name,
        artist: authorName,
        album: podcast.name,
        duration: seconds != null ? Duration(seconds: seconds) : null,
        artUri: e.thumbnails.isNotEmpty
            ? Uri.tryParse(e.thumbnails.last.url)
            : AaContentStyles.drawableUri('cover_podcasts'),
        publishDate: e.date,
      );
      items.add(
        track
            .toFreshMediaItem(
              additionalExtras: AaContentStyles.styleExtras(
                playable: AaContentStyles.styleList,
              ),
            )
            .copyWith(
              id: AaMediaId.playTrack(
                contextKind: AaMediaId.ctxPodcast,
                contextId: browseId,
                index: i,
                videoId: e.videoId,
              ),
            ),
      );
    }

    return items;
  }

  Future<List<MediaItem>> buildAlbumChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final rawId = parentMediaId.substring(AaMediaId.albumPrefix.length);
    final albumId = await _musicRepo.resolveAlbumId(rawId);
    final (album, liked) = await (
      _musicRepo.getAlbum(albumId),
      _libraryRepo.getLikedAlbum(albumId),
    ).wait;

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxAlbum, albumId),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, AaMediaId.ctxAlbum, albumId),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actAffinity,
          AaMediaId.ctxAlbum,
          albumId,
        ),
        title: liked != null ? l10n.aaUnlike : l10n.aaLike,
        artUri: AaContentStyles.drawableUri(
          liked != null ? 'ic_favorite' : 'ic_favorite_border',
        ),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    final songs = playableSongs(album.songs).take(100).toList(growable: false);
    for (var i = 0; i < songs.length; i++) {
      final s = songs[i];
      final track = QueueTrack(
        videoId: s.videoId,
        needsUrl: true,
        isVideo: s.type == 'VIDEO',
        isExplicit: s.isExplicit,
        artistId: primaryArtistId(s.artists),
        albumId: albumId,
        artistsJson: encodeArtistsJson(s.artists),
        title: s.name,
        artist: displayArtists(s.artists),
        album: album.name,
        duration: Duration(seconds: s.duration ?? 0),
        artUri: album.thumbnails.isNotEmpty
            ? Uri.tryParse(album.thumbnails.last.url)
            : null,
      );
      items.add(
        track
            .toFreshMediaItem(
              additionalExtras: AaContentStyles.styleExtras(
                playable: AaContentStyles.styleList,
                isExplicit: s.isExplicit,
              ),
            )
            .copyWith(
              id: AaMediaId.playTrack(
                contextKind: AaMediaId.ctxAlbum,
                contextId: albumId,
                index: i,
                videoId: s.videoId,
              ),
            ),
      );
    }
    return items;
  }

  Future<List<MediaItem>> buildRemotePlaylistChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final playlistId = parentMediaId.substring(
      AaMediaId.remotePlaylistPrefix.length,
    );
    final (videos, liked) = await (
      _musicRepo.getPlaylistVideos(playlistId),
      _libraryRepo.getLikedPlaylist(playlistId),
    ).wait;

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actPlay,
          AaMediaId.ctxPlaylist,
          playlistId,
        ),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actShuffle,
          AaMediaId.ctxPlaylist,
          playlistId,
        ),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(
          AaMediaId.actAffinity,
          AaMediaId.ctxPlaylist,
          playlistId,
        ),
        title: liked != null ? l10n.unlikePlaylist : l10n.likePlaylist,
        artUri: AaContentStyles.drawableUri(
          liked != null ? 'ic_favorite' : 'ic_favorite_border',
        ),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    final playable = playableVideos(videos).take(100).toList(growable: false);
    for (var i = 0; i < playable.length; i++) {
      items.add(
        AaContentMapper.videoToMediaItem(
          playable[i],
          contextKind: AaMediaId.ctxPlaylist,
          contextId: playlistId,
          contextIndex: i,
        ),
      );
    }
    return items;
  }

  Future<List<MediaItem>> buildHistoryChildren(AppLocalizations l10n) async {
    final history = await _libraryRepo.getRecentHistory(limit: 50);
    if (history.isEmpty) return const [];
    return [
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxHistory, 'all'),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, AaMediaId.ctxHistory, 'all'),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      for (var i = 0; i < history.length; i++)
        AaContentMapper.historyToMediaItem(history[i], index: i),
    ];
  }

  Future<List<dynamic>> fetchMixSongs(String mixKind) {
    switch (mixKind) {
      case 'most_played':
        return _libraryRepo.getMostPlayedSongs(limit: 50);
      case 'recently_played':
        return _libraryRepo.getRecentHistory(limit: 50);
      case 'forgotten_favorites':
        return _libraryRepo.getForgottenFavorites(daysLimit: 30);
      default:
        return Future.value(const []);
    }
  }

  Future<List<MediaItem>> buildMixChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final mixKind = parentMediaId.substring(AaMediaId.mixPrefix.length);
    final songs = await fetchMixSongs(mixKind);
    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxMix, mixKind),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, AaMediaId.ctxMix, mixKind),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    for (var i = 0; i < songs.length; i++) {
      final s = songs[i];
      if (s is HistoryModel) {
        items.add(
          AaContentMapper.historyToMediaItem(
            s,
            index: i,
            contextKind: AaMediaId.ctxMix,
            contextId: mixKind,
          ),
        );
      } else if (s is LikedSongModel) {
        items.add(
          AaContentMapper.likedSongToMediaItem(
            s,
            index: i,
            contextKind: AaMediaId.ctxMix,
            contextId: mixKind,
          ),
        );
      }
    }
    return items;
  }

  Future<List<MediaItem>> buildAskMixChildren(
    String parentMediaId,
    AppLocalizations l10n,
  ) async {
    final rest = parentMediaId.substring(AaMediaId.askMixPrefix.length);
    final sep = rest.lastIndexOf(':');
    if (sep <= 0) return const [];
    final messageId = rest.substring(0, sep);
    final attIdx = int.tryParse(rest.substring(sep + 1));
    if (attIdx == null) return const [];

    final mix = await _homeBuilder.findAskMix(messageId, attIdx);
    if (mix == null || mix.tracks.isEmpty) return const [];

    final ctxId = '$messageId:$attIdx';
    return [
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, AaMediaId.ctxAskMix, ctxId),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, AaMediaId.ctxAskMix, ctxId),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      for (var i = 0; i < mix.tracks.length; i++)
        AaContentMapper.askTrackToMediaItem(
          mix.tracks[i],
          contextId: ctxId,
          index: i,
        ),
    ];
  }
}
