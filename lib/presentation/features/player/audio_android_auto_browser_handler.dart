import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../domain/usecases/player/play_smart_mix_use_case.dart';
import '../../../domain/usecases/home/get_discover_suggestions_use_case.dart';
import '../../../domain/usecases/home/get_new_releases_use_case.dart';
import '../../../domain/usecases/home/get_similar_artists_suggestions_use_case.dart';
import 'audio_handler.dart';

class AudioAndroidAutoBrowserHandler {
  final SonoraAudioHandler _audioHandler;

  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final PlayAlbumUseCase _playAlbumUseCase;
  final PlayPlaylistUseCase _playPlaylistUseCase;
  final PlaySmartMixUseCase _playSmartMixUseCase;
  final GetNewReleasesUseCase _getNewReleasesUseCase;
  final GetDiscoverSuggestionsUseCase _getDiscoverSuggestionsUseCase;
  final GetSimilarArtistsSuggestionsUseCase
  _getSimilarArtistsSuggestionsUseCase;
  // Injected by the caller so no extra Connectivity instance is created.
  final Connectivity _connectivity;

  // ── Android Auto extras ──────────────────────────────────────────────────────
  static const String _kContentStyleBrowsable =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const String _kContentStylePlayable =
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const int _kStyleList = 1;
  static const int _kStyleGrid = 2;

  // ── AA browse-tree action IDs ──────────────────────────────────────────────
  static const String _actionPlayAlbum = '__action__:play_album:';
  static const String _actionShuffleAlbum = '__action__:shuffle_album:';
  static const String _actionLikeAlbum = '__action__:like_album:';
  static const String _actionPlayArtist = '__action__:play_artist:';
  static const String _actionShuffleArtist = '__action__:shuffle_artist:';
  static const String _actionFollowArtist = '__action__:follow_artist:';
  static const String _actionPlayPlaylist = '__action__:play_playlist:';
  static const String _actionShufflePlaylist = '__action__:shuffle_playlist:';
  static const String _actionLikePlaylist = '__action__:like_playlist:';

  // ── AA content tree IDs ──────────────────────────────────────────────────────
  static const String _rootId = '/';
  static const String _homeId = '__home__';
  static const String _libraryId = '__library__';
  static const String _exploreId = '__explore__';
  static const String _likedId = '__liked__';
  static const String _playlistsId = '__playlists__';
  static const String _artistsId = '__artists__';
  static const String _albumsId = '__albums__';
  static const String _historyId = '__history__';
  static const String _homeSectionPrefix = '__home_section__:';
  static const String _playlistPrefix = '__playlist__:';
  static const String _artistPrefix = '__artist__:';
  static const String _homeAlbumPrefix = '__home_album__:';
  static const String _homePlaylistPrefix = '__home_playlist__:';
  static const String _mixesId = '__mixes__';
  static const String _newReleasesId = '__new_releases__';
  static const String _discoverId = '__discover__';
  static const String _similarArtistsId = '__similar_artists__';
  static const String _downloadsId = '__downloads__';
  static const String _mixPrefix = '__mix__:';
  static const String _actionPlayMix = '__action__:play_mix:';
  static const String _actionShuffleMix = '__action__:shuffle_mix:';
  static const String _actionPlayDownloads = '__action__:play_downloads:';
  static const String _actionShuffleDownloads = '__action__:shuffle_downloads:';

  AudioAndroidAutoBrowserHandler({
    required SonoraAudioHandler audioHandler,
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required PlayAlbumUseCase playAlbumUseCase,
    required PlayPlaylistUseCase playPlaylistUseCase,
    required PlaySmartMixUseCase playSmartMixUseCase,
    required GetNewReleasesUseCase getNewReleasesUseCase,
    required GetDiscoverSuggestionsUseCase getDiscoverSuggestionsUseCase,
    required GetSimilarArtistsSuggestionsUseCase
    getSimilarArtistsSuggestionsUseCase,
    required Connectivity connectivity,
  }) : _audioHandler = audioHandler,
       _musicRepo = musicRepo,
       _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase,
       _playAlbumUseCase = playAlbumUseCase,
       _playPlaylistUseCase = playPlaylistUseCase,
       _playSmartMixUseCase = playSmartMixUseCase,
       _getNewReleasesUseCase = getNewReleasesUseCase,
       _getDiscoverSuggestionsUseCase = getDiscoverSuggestionsUseCase,
       _getSimilarArtistsSuggestionsUseCase =
           getSimilarArtistsSuggestionsUseCase,
       _connectivity = connectivity;

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — getChildren (AA browse tree)
  // ═══════════════════════════════════════════════════════════════

  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    dev.log('[AA] getChildren: "$parentMediaId"');
    // audio_service returns BrowserRoot("/") to AA, so the root parentMediaId is "/"
    final isRoot =
        parentMediaId == _rootId ||
        parentMediaId == 'root' ||
        parentMediaId == 'root_id' ||
        parentMediaId.isEmpty;
    try {
      if (isRoot) return _buildRootChildren();

      switch (parentMediaId) {
        // Top-level tabs
        case _homeId:
          return _buildHomeChildren();
        case _mixesId:
          return _buildMixesChildren();
        case _libraryId:
          return _buildLibraryChildren();
        case _exploreId:
          return _buildExploreChildren();

        // Library sub-nodes
        case _likedId:
          return _buildLikedChildren();
        case _playlistsId:
          return _buildPlaylistFolders();
        case _artistsId:
          return _buildArtistFolders();
        case _albumsId:
          return _buildLikedAlbumFolders();
        case _historyId:
          return _buildRecentChildren();
        case _downloadsId:
          return _buildDownloadChildren();
        case _newReleasesId:
          return _buildNewReleasesChildren();
        case _discoverId:
          return _buildDiscoverChildren();
        case _similarArtistsId:
          return _buildSimilarArtistsChildren();

        // Dynamic prefixes
        default:
          if (parentMediaId.startsWith(_mixPrefix)) {
            return _buildMixSongChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homeSectionPrefix)) {
            return _buildHomeSectionChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_playlistPrefix)) {
            return _buildPlaylistEntryChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_artistPrefix)) {
            return _buildArtistChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homeAlbumPrefix)) {
            return _buildHomeAlbumSongChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homePlaylistPrefix)) {
            return _buildHomePlaylistVideoChildren(parentMediaId);
          }
          return [];
      }
    } catch (e, st) {
      dev.log('[AA] getChildren error for "$parentMediaId": $e\n$st');
      return [];
    }
  }

  Future<bool> _isOffline() async {
    final results = await _connectivity.checkConnectivity();
    return results.length == 1 && results.contains(ConnectivityResult.none);
  }

  List<MediaItem> _buildRootChildren() {
    return [
      MediaItem(
        id: _homeId,
        title: 'Home',
        displaySubtitle: 'For you',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _mixesId,
        title: 'Mixes',
        displaySubtitle: 'Smart mixes',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleGrid,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _libraryId,
        title: 'Library',
        displaySubtitle: 'Your music',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _exploreId,
        title: 'Explore',
        displaySubtitle: 'Discover new music',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
    ];
  }

  Future<List<MediaItem>> _buildLibraryChildren() async {
    return [
      MediaItem(
        id: _likedId,
        title: 'Favorites',
        displaySubtitle: 'Your liked songs',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _artistsId,
        title: 'Artists',
        displaySubtitle: 'Followed artists',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleGrid,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _playlistsId,
        title: 'Playlists',
        displaySubtitle: 'Your playlists',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleGrid,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _albumsId,
        title: 'Albums',
        displaySubtitle: 'Liked albums',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleGrid,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _historyId,
        title: 'History',
        displaySubtitle: 'Recent history',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _downloadsId,
        title: 'Downloads',
        displaySubtitle: 'Offline music',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
    ];
  }

  Future<List<MediaItem>> _buildHomeChildren() async {
    final isOff = await _isOffline();
    final items = <MediaItem>[];

    if (isOff) {
      // Offline mode: only local sections
      await _addLocalHomeSections(items);
      return items;
    }

    // Online mode: first YTM section + local sections
    try {
      final result = await _musicRepo.getHome();
      final sections = result.sections;
      dev.log('[AA] getHome returned ${sections.length} sections');

      // 1. Add YTM Feed Section 0
      if (sections.isNotEmpty) {
        final section = sections[0];
        if (section.contents.isNotEmpty) {
          final sectionItems =
              section.contents.expand(_contentToMediaItems).toList();
          if (sectionItems.isNotEmpty) {
            items.add(
              MediaItem(
                id: '${_homeSectionPrefix}0',
                title: section.title,
                playable: false,
                extras: {
                  _kContentStyleBrowsable: _kStyleList,
                  _kContentStylePlayable: _kStyleList,
                },
              ),
            );
            items.addAll(sectionItems.take(3));
          }
        }
      }

      // 2. Add local sections
      await _addLocalHomeSections(items);
    } catch (e, st) {
      dev.log(
        '[AA] Error building online home, falling back to offline: $e\n$st',
      );
      items.clear();
      await _addLocalHomeSections(items);
    }

    return items;
  }

  Future<void> _addLocalHomeSections(List<MediaItem> items) async {
    // 1. Continue Listening (recent history) — most useful while driving
    final recent = await _buildRecentChildren();
    if (recent.isNotEmpty) {
      items.add(
        MediaItem(
          id: _historyId,
          title: 'Continue Listening',
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(recent.take(3));
    }

    // 2. Playlists (local + liked)
    final playlists = await _buildPlaylistFolders();
    if (playlists.isNotEmpty) {
      items.add(
        MediaItem(
          id: _playlistsId,
          title: 'Your Playlists',
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleGrid,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(playlists.take(3));
    }

    // 3. Your Artists (followed artists)
    final artists = await _buildArtistFolders();
    if (artists.isNotEmpty) {
      items.add(
        MediaItem(
          id: _artistsId,
          title: 'Your Artists',
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleGrid,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(artists.take(3));
    }

    // 4. Liked Albums
    final albums = await _buildLikedAlbumFolders();
    if (albums.isNotEmpty) {
      items.add(
        MediaItem(
          id: _albumsId,
          title: 'Liked Albums',
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleGrid,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(albums.take(3));
    }
  }

  Future<List<MediaItem>> _buildExploreChildren() async {
    final isOff = await _isOffline();
    if (isOff) {
      // Explore is mostly online content.
      return [];
    }

    final items = <MediaItem>[];
    try {
      final result = await _musicRepo.getHome();
      final sections = result.sections;
      dev.log('[AA] getHome returned ${sections.length} sections for explore');

      // 1. New Releases (from followed artists)
      try {
        final releases = await _getNewReleasesUseCase.execute();
        if (releases.isNotEmpty) {
          final releaseItems =
              releases
                  .map(
                    (a) => MediaItem(
                      id: '$_homeAlbumPrefix${a.albumId}',
                      title: a.name,
                      artist: a.artist.name,
                      artUri:
                          a.thumbnails.isNotEmpty
                              ? Uri.tryParse(a.thumbnails.last.url)
                              : null,
                      playable: false,
                      extras: {
                        _kContentStyleBrowsable: _kStyleGrid,
                        _kContentStylePlayable: _kStyleList,
                      },
                    ),
                  )
                  .toList();

          items.add(
            MediaItem(
              id: _newReleasesId,
              title: 'New Releases',
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleGrid,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
          items.addAll(releaseItems.take(3));
        }
      } catch (e) {
        dev.log('[AA] Failed to load new releases for explore: $e');
      }

      // 2. Discover (recommendations)
      try {
        final suggestions = await _getDiscoverSuggestionsUseCase.execute();
        if (suggestions.isNotEmpty) {
          final discoverItems =
              suggestions
                  .map(
                    (song) => MediaItem(
                      id: song.videoId,
                      title: song.title,
                      artist: song.artists.name,
                      artUri:
                          song.thumbnails.isNotEmpty
                              ? Uri.tryParse(song.thumbnails.last.url)
                              : null,
                      duration: Duration(seconds: song.duration),
                      extras: {
                        'needsUrl': true,
                        'videoId': song.videoId,
                        'isVideo': song.type == 'VIDEO',
                        'isExplicit': song.isExplicit,
                        _kContentStylePlayable: _kStyleList,
                      },
                    ),
                  )
                  .toList();

          items.add(
            MediaItem(
              id: _discoverId,
              title: 'Discover',
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
          items.addAll(discoverItems.take(3));
        }
      } catch (e) {
        dev.log('[AA] Failed to load discover suggestions for explore: $e');
      }

      // 3. Similar Artists
      try {
        final similar = await _getSimilarArtistsSuggestionsUseCase.execute();
        if (similar.isNotEmpty) {
          final similarItems =
              similar
                  .map(
                    (a) => MediaItem(
                      id: '$_artistPrefix${a.artistId}',
                      title: a.name,
                      artUri:
                          a.thumbnails.isNotEmpty
                              ? Uri.tryParse(a.thumbnails.last.url)
                              : null,
                      playable: false,
                      extras: {
                        _kContentStyleBrowsable: _kStyleGrid,
                        _kContentStylePlayable: _kStyleList,
                      },
                    ),
                  )
                  .toList();

          items.add(
            MediaItem(
              id: _similarArtistsId,
              title: 'Similar Artists',
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleGrid,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
          items.addAll(similarItems.take(3));
        }
      } catch (e) {
        dev.log('[AA] Failed to load similar artists for explore: $e');
      }

      // 4. YTM Feed Sections 1..N
      if (sections.length > 1) {
        for (var i = 1; i < sections.length; i++) {
          final section = sections[i];
          if (section.contents.isEmpty) continue;
          final sectionItems =
              section.contents.expand(_contentToMediaItems).toList();
          if (sectionItems.isEmpty) continue;
          items.add(
            MediaItem(
              id: '$_homeSectionPrefix$i',
              title: section.title,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
          items.addAll(sectionItems.take(3));
        }
      }
    } catch (e, st) {
      dev.log('[AA] Error building explore: $e\n$st');
    }

    return items;
  }

  List<MediaItem> _contentToMediaItems(dynamic content) {
    if (content is SongDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          album: content.album?.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': content.type == 'VIDEO',
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is VideoDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': true,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is AlbumDetailed) {
      return [
        MediaItem(
          id: '$_homeAlbumPrefix${content.albumId}',
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is PlaylistDetailed) {
      return [
        MediaItem(
          id: '$_homePlaylistPrefix${content.playlistId}',
          title: content.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    }
    return [];
  }

  Future<List<MediaItem>> _buildHomeSectionChildren(
    String parentMediaId,
  ) async {
    final index = int.tryParse(
      parentMediaId.substring(_homeSectionPrefix.length),
    );
    if (index == null) return [];
    final result = await _musicRepo.getHome();
    final sections = result.sections;
    if (index >= sections.length) return [];
    final section = sections[index];
    return section.contents.expand(_contentToMediaItems).toList();
  }

  Future<List<MediaItem>> _buildRecentChildren() async {
    final history = await _libraryRepo.getRecentHistory(limit: 50);
    return history
        .map(
          (h) => MediaItem(
            id: h.videoId,
            title: h.title,
            artist: h.artist,
            artUri:
                h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
            extras: {
              'needsUrl': true,
              'videoId': h.videoId,
              'isVideo': h.isVideo,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildDownloadMediaItems() async {
    final downloads = await _libraryRepo.getAllDownloads();
    return downloads
        .where((d) => d.status == 'completed' && d.localPath != null)
        .map(
          (d) => MediaItem(
            id: d.videoId,
            title: d.title,
            artist: d.artist,
            artUri:
                d.thumbnailUrl != null ? Uri.tryParse(d.thumbnailUrl!) : null,
            duration: Duration.zero,
            extras: {
              'url': Uri.file(d.localPath!).toString(),
              'videoId': d.videoId,
              'isVideo': d.isVideo,
              'isExplicit': d.isExplicit,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildDownloadChildren() async {
    final items = await _buildDownloadMediaItems();
    if (items.isEmpty) return [];

    return [
      MediaItem(
        id: _actionPlayDownloads,
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: _actionShuffleDownloads,
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      // AA has practical limits on browse-tree items; cap downloads to 100.
      ...items.take(100),
    ];
  }

  Future<List<MediaItem>> _buildLikedChildren() async {
    final songs = await _libraryRepo.getAllLikedSongs();
    return songs
        .map(
          (s) => MediaItem(
            id: s.videoId,
            title: s.title,
            artist: s.artist,
            artUri:
                s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
            extras: {
              'needsUrl': true,
              'videoId': s.videoId,
              'isVideo': s.isVideo,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistFolders() async {
    final (local, liked) =
        await (
          _libraryRepo.getAllPlaylists(),
          _libraryRepo.getAllLikedPlaylists(),
        ).wait;

    return [
      ...local.map(
        (p) => MediaItem(
          id: '$_playlistPrefix${p.id}',
          title: p.name,
          displaySubtitle: 'Local Playlist',
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ),
      ...liked.map(
        (p) => MediaItem(
          id: '$_homePlaylistPrefix${p.playlistId}',
          title: p.name,
          displaySubtitle: 'Liked Playlist',
          artUri: p.thumbnailUrl != null ? Uri.tryParse(p.thumbnailUrl!) : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ),
    ];
  }

  Future<List<MediaItem>> _localPlaylistToMediaItems(int playlistId) async {
    final (entries, allLiked) =
        await (
          _libraryRepo.getPlaylistEntries(playlistId),
          _libraryRepo.getAllLikedSongs(),
        ).wait;

    final likedByVideoId = <String, LikedSongModel>{
      for (final s in allLiked) s.videoId: s,
    };

    return [
      for (final entry in entries)
        MediaItem(
          id: entry.videoId,
          title:
              likedByVideoId[entry.videoId]?.title ??
              entry.title ??
              entry.videoId,
          artist: likedByVideoId[entry.videoId]?.artist ?? entry.artist ?? '',
          artUri:
              (likedByVideoId[entry.videoId]?.thumbnailUrl ??
                          entry.thumbnailUrl) !=
                      null
                  ? Uri.tryParse(
                    likedByVideoId[entry.videoId]?.thumbnailUrl ??
                        entry.thumbnailUrl!,
                  )
                  : null,
          duration: Duration.zero,
          extras: {
            'needsUrl': true,
            'videoId': entry.videoId,
            'isVideo': likedByVideoId[entry.videoId]?.isVideo ?? entry.isVideo,
            _kContentStylePlayable: _kStyleList,
          },
        ),
    ];
  }

  Future<List<MediaItem>> _buildMixesChildren() async {
    return _buildMixesFolder();
  }

  List<MediaItem> _buildMixesFolder() {
    return [
      MediaItem(
        id: '${_mixPrefix}most_played',
        title: 'Most Played',
        displaySubtitle: 'Your most played tracks',
        playable: false,
        artUri: Uri.parse(
          'android.resource://com.gmstyle.sonora/drawable/cover_most_played',
        ),
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: '${_mixPrefix}recently_played',
        title: 'Recently Played',
        displaySubtitle: 'Your recently played tracks',
        playable: false,
        artUri: Uri.parse(
          'android.resource://com.gmstyle.sonora/drawable/cover_recently_played',
        ),
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: '${_mixPrefix}forgotten_favorites',
        title: 'Forgotten Favorites',
        displaySubtitle: 'Tracks you used to love',
        playable: false,
        artUri: Uri.parse(
          'android.resource://com.gmstyle.sonora/drawable/cover_forgotten_favorites',
        ),
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
    ];
  }

  Future<List<MediaItem>> _buildMixSongChildren(String parentMediaId) async {
    final mixTypeStr = parentMediaId.substring(_mixPrefix.length);
    final songs = await _fetchMixSongs(mixTypeStr);

    final songItems =
        songs.map((s) {
          final isVideo =
              s is HistoryModel
                  ? s.isVideo
                  : s is LikedSongModel
                  ? s.isVideo
                  : false;
          final isExplicit =
              s is HistoryModel
                  ? s.isExplicit
                  : s is LikedSongModel
                  ? s.isExplicit
                  : false;
          return MediaItem(
            id: s.videoId,
            title: s.title,
            artist: s.artist,
            artUri:
                s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
            duration:
                s.duration != null ? Duration(seconds: s.duration!) : null,
            extras: {
              'needsUrl': true,
              'videoId': s.videoId,
              'isVideo': isVideo,
              'isExplicit': isExplicit,
              _kContentStylePlayable: _kStyleList,
            },
          );
        }).toList();

    return [
      MediaItem(
        id: '$_actionPlayMix$mixTypeStr',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleMix$mixTypeStr',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      ...songItems,
    ];
  }

  Future<List<dynamic>> _fetchMixSongs(String mixTypeStr) async {
    if (mixTypeStr == 'most_played') {
      return _libraryRepo.getMostPlayedSongs(limit: 50);
    } else if (mixTypeStr == 'recently_played') {
      return _libraryRepo.getRecentHistory(limit: 50);
    } else if (mixTypeStr == 'forgotten_favorites') {
      return _libraryRepo.getForgottenFavorites(daysLimit: 30);
    }
    return [];
  }

  Future<List<MediaItem>> _buildNewReleasesChildren() async {
    final releases = await _getNewReleasesUseCase.execute();
    return releases
        .map(
          (a) => MediaItem(
            id: '$_homeAlbumPrefix${a.albumId}',
            title: a.name,
            artist: a.artist.name,
            artUri:
                a.thumbnails.isNotEmpty
                    ? Uri.tryParse(a.thumbnails.last.url)
                    : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildDiscoverChildren() async {
    final suggestions = await _getDiscoverSuggestionsUseCase.execute();
    return suggestions
        .map(
          (song) => MediaItem(
            id: song.videoId,
            title: song.title,
            artist: song.artists.name,
            artUri:
                song.thumbnails.isNotEmpty
                    ? Uri.tryParse(song.thumbnails.last.url)
                    : null,
            duration: Duration(seconds: song.duration),
            extras: {
              'needsUrl': true,
              'videoId': song.videoId,
              'isVideo': song.type == 'VIDEO',
              'isExplicit': song.isExplicit,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildSimilarArtistsChildren() async {
    final similar = await _getSimilarArtistsSuggestionsUseCase.execute();
    return similar
        .map(
          (a) => MediaItem(
            id: '$_artistPrefix${a.artistId}',
            title: a.name,
            artUri:
                a.thumbnails.isNotEmpty
                    ? Uri.tryParse(a.thumbnails.last.url)
                    : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistEntryChildren(
    String parentMediaId,
  ) async {
    final playlistId = int.tryParse(
      parentMediaId.substring(_playlistPrefix.length),
    );
    if (playlistId == null) {
      dev.log('[AA] _buildPlaylistEntryChildren: invalid id "$parentMediaId"');
      return [];
    }
    final playlistIdStr = playlistId.toString();

    final songItems = await _localPlaylistToMediaItems(playlistId);

    return [
      MediaItem(
        id: '$_actionPlayPlaylist$playlistIdStr',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistIdStr',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      ...songItems,
    ];
  }

  Future<List<MediaItem>> _buildArtistFolders() async {
    final artists = await _libraryRepo.getAllFollowedArtists();
    return artists
        .map(
          (a) => MediaItem(
            id: '$_artistPrefix${a.artistId}',
            title: a.name,
            displaySubtitle: 'Artist',
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildArtistChildren(String parentMediaId) async {
    final artistId = parentMediaId.substring(_artistPrefix.length);
    final artistInfo = await _musicRepo.getArtist(artistId);
    final followed = await _libraryRepo.getFollowedArtist(artistId);

    final mediaItems = <MediaItem>[
      MediaItem(
        id: '$_actionPlayArtist$artistId',
        title: 'Play Top Songs',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleArtist$artistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionFollowArtist$artistId',
        title: followed != null ? 'Following' : 'Follow',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    // 1. Top Songs (Playable)
    for (final song in artistInfo.topSongs) {
      mediaItems.add(
        MediaItem(
          id: song.videoId,
          title: song.name,
          artist: song.artist.name,
          artUri:
              song.thumbnails.isNotEmpty
                  ? Uri.tryParse(song.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: song.duration ?? 0),
          playable: true,
          extras: {
            'needsUrl': true,
            'videoId': song.videoId,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 2. Albums (Browsable folders)
    for (final album in artistInfo.topAlbums) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${album.albumId}',
          title: album.name,
          artist: 'Album',
          artUri:
              album.thumbnails.isNotEmpty
                  ? Uri.tryParse(album.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 3. Singles (Browsable folders)
    for (final single in artistInfo.topSingles) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${single.albumId}',
          title: single.name,
          artist: 'Single',
          artUri:
              single.thumbnails.isNotEmpty
                  ? Uri.tryParse(single.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 4. Featured On (Playlists - Browsable folders)
    for (final playlist in artistInfo.featuredOn) {
      mediaItems.add(
        MediaItem(
          id: '$_homePlaylistPrefix${playlist.playlistId}',
          title: playlist.name,
          artist: 'Playlist',
          artUri:
              playlist.thumbnails.isNotEmpty
                  ? Uri.tryParse(playlist.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 5. Similar Artists (Browsable folders)
    for (final related in artistInfo.similarArtists) {
      mediaItems.add(
        MediaItem(
          id: '$_artistPrefix${related.artistId}',
          title: related.name,
          artist: 'Artist',
          artUri:
              related.thumbnails.isNotEmpty
                  ? Uri.tryParse(related.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    return mediaItems;
  }

  Future<List<MediaItem>> _buildLikedAlbumFolders() async {
    final albums = await _libraryRepo.getAllLikedAlbums();
    return albums
        .map(
          (a) => MediaItem(
            id: '$_homeAlbumPrefix${a.albumId}',
            title: a.name,
            artist: a.artistName,
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildHomeAlbumSongChildren(
    String parentMediaId,
  ) async {
    final albumId = parentMediaId.substring(_homeAlbumPrefix.length);
    final album = await _musicRepo.getAlbum(albumId);
    final liked = await _libraryRepo.getLikedAlbum(albumId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayAlbum$albumId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleAlbum$albumId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikeAlbum$albumId',
        title: liked != null ? 'Unlike Album' : 'Like Album',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      album.songs
          .take(100)
          .map(
            (s) => MediaItem(
              id: s.videoId,
              title: s.name,
              artist: s.artist.name,
              album: album.name,
              artUri:
                  album.thumbnails.isNotEmpty
                      ? Uri.tryParse(album.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: s.duration ?? 0),
              extras: {
                'needsUrl': true,
                'videoId': s.videoId,
                'isVideo': s.type == 'VIDEO',
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
  }

  Future<List<MediaItem>> _buildHomePlaylistVideoChildren(
    String parentMediaId,
  ) async {
    final playlistId = parentMediaId.substring(_homePlaylistPrefix.length);
    final videos = await _musicRepo.getPlaylistVideos(playlistId);
    final liked = await _libraryRepo.getLikedPlaylist(playlistId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayPlaylist$playlistId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikePlaylist$playlistId',
        title: liked != null ? 'Unlike Playlist' : 'Like Playlist',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      videos
          .take(100)
          .map(
            (v) => MediaItem(
              id: v.videoId,
              title: v.name,
              artist: v.artist.name,
              artUri:
                  v.thumbnails.isNotEmpty
                      ? Uri.tryParse(v.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: v.duration ?? 0),
              extras: {
                'needsUrl': true,
                'videoId': v.videoId,
                'isVideo': true,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromMediaId
  // ═══════════════════════════════════════════════════════════════

  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      // ── Album actions ────────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayAlbum)) {
        final albumId = mediaId.substring(_actionPlayAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final items = await _playAlbumUseCase.execute(album.songs);
        await _audioHandler.playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleAlbum)) {
        final albumId = mediaId.substring(_actionShuffleAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final shuffled = List<SongDetailed>.from(album.songs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await _audioHandler.playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionLikeAlbum)) {
        final albumId = mediaId.substring(_actionLikeAlbum.length);
        final existing = await _libraryRepo.getLikedAlbum(albumId);
        if (existing != null) {
          await _libraryRepo.deleteLikedAlbum(albumId);
        } else {
          final album = await _musicRepo.getAlbum(albumId);
          await _libraryRepo.toggleLikedAlbum(
            LikedAlbumModel(
              albumId: albumId,
              name: album.name,
              artistName: album.artist.name,
              artistId: album.artist.artistId,
              thumbnailUrl:
                  album.thumbnails.isNotEmpty
                      ? album.thumbnails.last.url
                      : null,
              year: album.year,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homeAlbumPrefix$albumId',
          ),
        );
        return;
      }

      // ── Artist actions ───────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayArtist)) {
        final artistId = mediaId.substring(_actionPlayArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final items = await _playAlbumUseCase.execute(artist.topSongs);
        await _audioHandler.playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleArtist)) {
        final artistId = mediaId.substring(_actionShuffleArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final shuffled = List<SongDetailed>.from(artist.topSongs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await _audioHandler.playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionFollowArtist)) {
        final artistId = mediaId.substring(_actionFollowArtist.length);
        final existing = await _libraryRepo.getFollowedArtist(artistId);
        if (existing != null) {
          await _libraryRepo.deleteFollowedArtist(artistId);
        } else {
          final artist = await _musicRepo.getArtist(artistId);
          await _libraryRepo.toggleFollowedArtist(
            FollowedArtistModel(
              artistId: artistId,
              name: artist.name,
              thumbnailUrl:
                  artist.thumbnails.isNotEmpty
                      ? artist.thumbnails.last.url
                      : null,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_artistPrefix$artistId',
          ),
        );
        return;
      }

      // ── Playlist actions ─────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayPlaylist)) {
        final playlistId = mediaId.substring(_actionPlayPlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          var items = await _localPlaylistToMediaItems(localId);
          if (items.isNotEmpty) {
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items = [
                items.first.copyWith(
                  extras: {
                    ...items.first.extras!,
                    'url': url,
                    'needsUrl': false,
                  },
                ),
                ...items.skip(1),
              ];
            } catch (_) {}
          }
          await _audioHandler.playNow(items);
        } else {
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final items = await _playPlaylistUseCase.execute(videos);
          await _audioHandler.playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionShufflePlaylist)) {
        final playlistId = mediaId.substring(_actionShufflePlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          var items = await _localPlaylistToMediaItems(localId);
          if (items.isNotEmpty) {
            items = List<MediaItem>.from(items)..shuffle();
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items[0] = items.first.copyWith(
                extras: {...items.first.extras!, 'url': url, 'needsUrl': false},
              );
            } catch (_) {}
          }
          await _audioHandler.playNow(items);
        } else {
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final shuffled = List<VideoDetailed>.from(videos)..shuffle();
          final items = await _playPlaylistUseCase.execute(shuffled);
          await _audioHandler.playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionLikePlaylist)) {
        final playlistId = mediaId.substring(_actionLikePlaylist.length);
        final existing = await _libraryRepo.getLikedPlaylist(playlistId);
        if (existing != null) {
          await _libraryRepo.deleteLikedPlaylist(playlistId);
        } else {
          final playlist = await _musicRepo.getPlaylist(playlistId);
          await _libraryRepo.toggleLikedPlaylist(
            LikedPlaylistModel(
              playlistId: playlistId,
              name: playlist.name,
              thumbnailUrl:
                  playlist.thumbnails.isNotEmpty
                      ? playlist.thumbnails.last.url
                      : null,
              videoCount: playlist.videoCount,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homePlaylistPrefix$playlistId',
          ),
        );
        return;
      }

      // ── Smart Mix actions ────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayMix)) {
        final mixTypeStr = mediaId.substring(_actionPlayMix.length);
        final songs = await _fetchMixSongs(mixTypeStr);
        final items = await _playSmartMixUseCase.execute(songs: songs);
        await _audioHandler.playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleMix)) {
        final mixTypeStr = mediaId.substring(_actionShuffleMix.length);
        final songs = await _fetchMixSongs(mixTypeStr);
        final shuffled = List<dynamic>.from(songs)..shuffle();
        final items = await _playSmartMixUseCase.execute(songs: shuffled);
        await _audioHandler.playNow(items);
        return;
      }

      // ── Downloads actions ────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayDownloads)) {
        final items = await _buildDownloadMediaItems();
        if (items.isNotEmpty) {
          await _audioHandler.playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionShuffleDownloads)) {
        final items = await _buildDownloadMediaItems();
        if (items.isNotEmpty) {
          final shuffled = List<MediaItem>.from(items)..shuffle();
          await _audioHandler.playNow(shuffled);
        }
        return;
      }

      // ── Default: single song play ───────────────────────────
      final item = await _playVideoIdUseCase.execute(mediaId);
      await _audioHandler.playNow([item]);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — search (FAB / text search → list of results)
  // ═══════════════════════════════════════════════════════════════

  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final futureArtists = _musicRepo.searchArtists(query);
      final futureSongs = _musicRepo.searchSongs(query);
      final futureAlbums = _musicRepo.searchAlbums(query);
      final futurePlaylists = _musicRepo.searchPlaylists(query);

      final results = await Future.wait([
        futureArtists,
        futureSongs,
        futureAlbums,
        futurePlaylists,
      ]);

      final artistsData = results[0];
      final songsData = results[1];
      final albumsData = results[2];
      final playlistsData = results[3];

      final artists = <MediaItem>[];
      final songs = <MediaItem>[];
      final albums = <MediaItem>[];
      final playlists = <MediaItem>[];

      // Mappatura Artisti
      for (final result in artistsData) {
        if (result is ArtistDetailed) {
          artists.add(
            MediaItem(
              id: '$_artistPrefix${result.artistId}',
              title: result.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Canzoni (e Video se presenti)
      for (final result in songsData) {
        if (result is SongDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {
                'needsUrl': true,
                'videoId': result.videoId,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        } else if (result is VideoDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {
                'needsUrl': true,
                'videoId': result.videoId,
                'isVideo': true,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Album
      for (final result in albumsData) {
        if (result is AlbumDetailed) {
          albums.add(
            MediaItem(
              id: '$_homeAlbumPrefix${result.albumId}',
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Playlist
      for (final result in playlistsData) {
        if (result is PlaylistDetailed) {
          playlists.add(
            MediaItem(
              id: '$_homePlaylistPrefix${result.playlistId}',
              title: result.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      return [...artists, ...songs, ...albums, ...playlists];
    } catch (e, st) {
      dev.log('[AA] search error for "$query": $e\n$st');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromSearch
  // ═══════════════════════════════════════════════════════════════

  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final results = await _musicRepo.searchSongs(query);
      if (results.isEmpty) return;
      // Resolve the first item eagerly for immediate playback start, then
      // queue the remaining results as lazy-resolved pending items so the
      // user can continue listening through the full set of search results.
      final firstItem = await _playVideoIdUseCase.execute(
        results.first.videoId,
      );
      final remaining = results.skip(1).expand(_contentToMediaItems).toList();
      await _audioHandler.playNow([firstItem, ...remaining]);
    } catch (e, st) {
      dev.log('[AA] playFromSearch error for "$query": $e\n$st');
    }
  }
}
