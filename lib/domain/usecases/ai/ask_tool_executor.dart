import 'dart:convert';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../core/utils/artists_utils.dart';
import '../../models/ask_chat_models.dart';
import '../../models/library_models.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/llm_chat_repository.dart';
import '../../repositories/music_repository.dart';

/// Lightweight snapshot of what the player is currently playing.
class AskNowPlayingSnapshot {
  const AskNowPlayingSnapshot({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    this.durationSec,
    this.isEpisode = false,
  });

  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final int? durationSec;
  final bool isEpisode;
}

/// Executes the 13 Sonora Ask Function Calling tools against Drift and YouTube
/// Music, enforcing the `useTasteContext` privacy gate, per-turn ID grounding,
/// and the Safe-Write policy (proposals only, never mutating Drift).
class AskToolExecutor {
  AskToolExecutor({
    required LibraryRepository libraryRepository,
    required MusicRepository musicRepository,
    this.readNowPlaying,
    this.useTasteContext = true,
  }) : _library = libraryRepository,
       _music = musicRepository;

  final LibraryRepository _library;
  final MusicRepository _music;
  final AskNowPlayingSnapshot? Function()? readNowPlaying;
  final bool useTasteContext;

  final Map<String, AskTrackRef> seenTracks = {};
  final Map<String, AskArtistRef> seenArtists = {};
  final Map<String, AskAlbumRef> seenAlbums = {};
  final Map<String, AskPlaylistRef> seenPlaylists = {};
  final Map<int, AskPlaylistRef> seenLocalPlaylists = {};
  final Map<String, AskPodcastRef> seenPodcasts = {};
  final Map<String, AskEpisodeRef> seenEpisodes = {};
  final List<AskAttachment> attachments = [];

  bool get hasSeenCatalogEntities =>
      seenTracks.isNotEmpty ||
      seenArtists.isNotEmpty ||
      seenAlbums.isNotEmpty ||
      seenPlaylists.isNotEmpty ||
      seenLocalPlaylists.isNotEmpty ||
      seenPodcasts.isNotEmpty ||
      seenEpisodes.isNotEmpty;

  static const _presentationToolNames = {
    'propose_mix',
    'propose_playlist_write',
    'present_catalog_items',
  };

  List<LlmToolDefinition> get presentationDefinitions => definitions
      .where((d) => _presentationToolNames.contains(d.name))
      .toList(growable: false);

  List<LlmToolDefinition> get definitions => const [
    LlmToolDefinition(
      name: 'get_taste_profile',
      description: 'Summarize the user\'s listening taste: top played tracks, top artists, total minutes, liked items, and local playlist names.',
      parameters: {'type': 'object', 'properties': {}},
    ),
    LlmToolDefinition(
      name: 'get_listening_history',
      description: 'Read recent listening history ordered by most recent play.',
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Max history rows to return (1-50, default 25).',
          },
        },
      },
    ),
    LlmToolDefinition(
      name: 'search_local_library',
      description: 'Search liked songs, albums, artists, playlists, and podcasts saved in the user library.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
          'scope': {
            'type': 'string',
            'enum': [
              'all',
              'songs',
              'albums',
              'artists',
              'playlists',
              'podcasts',
            ],
          },
        },
        'required': ['query'],
      },
    ),
    LlmToolDefinition(
      name: 'get_local_playlist_tracks',
      description: 'List tracks inside one of the user\'s local playlists by id or name.',
      parameters: {
        'type': 'object',
        'properties': {
          'playlistId': {'type': 'integer'},
          'playlistName': {'type': 'string'},
        },
      },
    ),
    LlmToolDefinition(
      name: 'get_now_playing',
      description: 'Get metadata of the track or episode currently playing.',
      parameters: {'type': 'object', 'properties': {}},
    ),
    LlmToolDefinition(
      name: 'search_catalog',
      description: 'Search YouTube Music catalog for songs, artists, albums, playlists, podcasts, or episodes.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
          'type': {
            'type': 'string',
            'enum': [
              'songs',
              'artists',
              'albums',
              'playlists',
              'podcasts',
              'episodes',
            ],
          },
          'limit': {'type': 'integer'},
        },
        'required': ['query'],
      },
    ),
    LlmToolDefinition(
      name: 'get_artist_info',
      description: 'Fetch artist details, top songs, albums, and similar artists from YouTube Music.',
      parameters: {
        'type': 'object',
        'properties': {
          'artistId': {'type': 'string'},
          'artistName': {'type': 'string'},
        },
      },
    ),
    LlmToolDefinition(
      name: 'get_song_related',
      description: 'Fetch related tracks (radio queue) for a given YouTube Music videoId.',
      parameters: {
        'type': 'object',
        'properties': {
          'videoId': {'type': 'string'},
          'limit': {'type': 'integer'},
        },
        'required': ['videoId'],
      },
    ),
    LlmToolDefinition(
      name: 'get_album_or_playlist',
      description: 'Fetch tracks of a YouTube Music album or playlist by ID.',
      parameters: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'kind': {
            'type': 'string',
            'enum': ['album', 'playlist'],
          },
        },
        'required': ['id', 'kind'],
      },
    ),
    LlmToolDefinition(
      name: 'get_charts_or_moods',
      description: 'Fetch YouTube Music charts or mood & genre categories.',
      parameters: {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['charts', 'moods'],
          },
          'country': {
            'type': 'string',
            'description': 'ISO 3166-1 alpha-2 country code or ZZ for Global.',
          },
        },
        'required': ['kind'],
      },
    ),
    LlmToolDefinition(
      name: 'get_song_lyrics',
      description: 'Fetch lyrics text for a YouTube Music song videoId.',
      parameters: {
        'type': 'object',
        'properties': {
          'videoId': {'type': 'string'},
        },
        'required': ['videoId'],
      },
    ),
    LlmToolDefinition(
      name: 'propose_mix',
      description: 'Attach an interactive playable mix card to the reply using ONLY videoIds returned earlier in this turn.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'subtitle': {'type': 'string'},
          'videoIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['title', 'videoIds'],
      },
    ),
    LlmToolDefinition(
      name: 'propose_playlist_write',
      description: 'Create a confirmation proposal to create or edit a local playlist (never saves automatically; user must confirm).',
      parameters: {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['create', 'append', 'remove'],
          },
          'playlistName': {'type': 'string'},
          'targetPlaylistId': {'type': 'integer'},
          'videoIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['operation', 'playlistName', 'videoIds'],
      },
    ),
    LlmToolDefinition(
      name: 'present_catalog_items',
      description: 'Attach interactive native Sonora cards (artists, tracks, albums, playlists, podcasts, or episodes) using ONLY verified IDs returned earlier in this turn.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'artistIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'trackVideoIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'albumIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'playlistIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'localPlaylistIds': {
            'type': 'array',
            'items': {'type': 'integer'},
          },
          'podcastBrowseIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'episodeVideoIds': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
      },
    ),
  ];

  Future<AskToolResult> execute(AskToolCall call) async {
    try {
      final result = await _dispatch(call.name, call.arguments);
      return AskToolResult(
        toolCallId: call.id,
        name: call.name,
        contentJson: jsonEncode(result),
      );
    } catch (e) {
      return AskToolResult(
        toolCallId: call.id,
        name: call.name,
        contentJson: jsonEncode({'error': e.toString()}),
        isError: true,
      );
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'get_taste_profile':
        return _getTasteProfile();
      case 'get_listening_history':
        return _getListeningHistory(args);
      case 'search_local_library':
        return _searchLocalLibrary(args);
      case 'get_local_playlist_tracks':
        return _getLocalPlaylistTracks(args);
      case 'get_now_playing':
        return _getNowPlaying();
      case 'search_catalog':
        return _searchCatalog(args);
      case 'get_artist_info':
        return _getArtistInfo(args);
      case 'get_song_related':
        return _getSongRelated(args);
      case 'get_album_or_playlist':
        return _getAlbumOrPlaylist(args);
      case 'get_charts_or_moods':
        return _getChartsOrMoods(args);
      case 'get_song_lyrics':
        return _getSongLyrics(args);
      case 'propose_mix':
        return _proposeMix(args);
      case 'propose_playlist_write':
        return _proposePlaylistWrite(args);
      case 'present_catalog_items':
        return _presentCatalogItems(args);
      default:
        return {'error': 'unknown_tool', 'name': name};
    }
  }

  Future<Map<String, dynamic>> _getTasteProfile() async {
    if (!useTasteContext) {
      return {'disabledByUser': true};
    }
    final mostPlayed = await _library.getMostPlayedSongs(limit: 30);
    final likedSongs = await _library.getAllLikedSongs();
    final followedArtists = await _library.getAllFollowedArtists();
    final playlists = await _library.getAllPlaylists();

    final artistCounts = <String, int>{};
    var totalSeconds = 0;
    for (final h in mostPlayed) {
      final artist = h.artist.trim();
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + h.playCount;
      }
      totalSeconds += (h.duration ?? 0) * h.playCount;
      _registerTrack(
        AskTrackRef(
          videoId: h.videoId,
          title: h.title,
          artist: h.artist,
          durationSec: h.duration,
          thumbnailUrl: h.thumbnailUrl,
          isExplicit: h.isExplicit,
          isVideo: h.isVideo,
        ),
      );
    }
    for (final s in likedSongs.take(25)) {
      _registerTrack(
        AskTrackRef(
          videoId: s.videoId,
          title: s.title,
          artist: s.artist,
          artistsJson: s.artistsJson,
          artistId: s.artistId,
          albumId: s.albumId,
          durationSec: s.duration,
          thumbnailUrl: s.thumbnailUrl,
          isExplicit: s.isExplicit,
          isVideo: s.isVideo,
        ),
      );
    }
    for (final a in followedArtists) {
      seenArtists.putIfAbsent(
        a.artistId,
        () => AskArtistRef(
          artistId: a.artistId,
          name: a.name,
          thumbnailUrl: a.thumbnailUrl,
        ),
      );
    }
    for (final p in playlists) {
      seenLocalPlaylists.putIfAbsent(
        p.id,
        () => AskPlaylistRef(
          localPlaylistId: p.id,
          name: p.name,
          artist: p.description,
        ),
      );
    }

    final topArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'estimatedMinutes': totalSeconds ~/ 60,
      'likedSongsCount': likedSongs.length,
      'followedArtistsCount': followedArtists.length,
      'topArtists': [
        for (final entry in topArtists.take(10))
          {'name': entry.key, 'plays': entry.value},
      ],
      'followedArtists': [
        for (final a in followedArtists.take(12))
          {'artistId': a.artistId, 'name': a.name},
      ],
      'topTracks': [
        for (final h in mostPlayed.take(15)) _trackSummary(h.videoId),
      ],
      'localPlaylists': [
        for (final p in playlists.take(15)) {'id': p.id, 'name': p.name},
      ],
    };
  }

  Future<Map<String, dynamic>> _getListeningHistory(
    Map<String, dynamic> args,
  ) async {
    if (!useTasteContext) {
      return {'disabledByUser': true};
    }
    final limit = ((args['limit'] as num?)?.toInt() ?? 25).clamp(1, 50);
    final rows = await _library.getRecentHistory(limit: limit);
    final out = <Map<String, dynamic>>[];
    for (final h in rows) {
      _registerTrack(
        AskTrackRef(
          videoId: h.videoId,
          title: h.title,
          artist: h.artist,
          durationSec: h.duration,
          thumbnailUrl: h.thumbnailUrl,
          isExplicit: h.isExplicit,
          isVideo: h.isVideo,
        ),
      );
      out.add({
        ..._trackSummary(h.videoId),
        'playCount': h.playCount,
        'playedAt': h.playedAt.toIso8601String(),
      });
    }
    return {'tracks': out};
  }

  Future<Map<String, dynamic>> _searchLocalLibrary(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query']?.toString() ?? '').trim().toLowerCase();
    final scope = (args['scope']?.toString() ?? 'all').trim().toLowerCase();
    if (query.isEmpty) return {'error': 'empty_query'};

    final out = <String, dynamic>{};

    if (scope == 'all' || scope == 'songs') {
      final songs = await _library.getAllLikedSongs();
      final matches = songs
          .where(
            (s) =>
                s.title.toLowerCase().contains(query) ||
                s.artist.toLowerCase().contains(query),
          )
          .take(15)
          .toList();
      for (final s in matches) {
        _registerTrack(
          AskTrackRef(
            videoId: s.videoId,
            title: s.title,
            artist: s.artist,
            artistsJson: s.artistsJson,
            artistId: s.artistId,
            albumId: s.albumId,
            durationSec: s.duration,
            thumbnailUrl: s.thumbnailUrl,
            isExplicit: s.isExplicit,
            isVideo: s.isVideo,
          ),
        );
      }
      out['songs'] = [for (final s in matches) _trackSummary(s.videoId)];
    }

    if (scope == 'all' || scope == 'artists') {
      final artists = await _library.getAllFollowedArtists();
      final matches = artists
          .where((a) => a.name.toLowerCase().contains(query))
          .take(12)
          .toList();
      for (final a in matches) {
        seenArtists.putIfAbsent(
          a.artistId,
          () => AskArtistRef(
            artistId: a.artistId,
            name: a.name,
            thumbnailUrl: a.thumbnailUrl,
          ),
        );
      }
      out['artists'] = [
        for (final a in matches) {'artistId': a.artistId, 'name': a.name},
      ];
    }

    if (scope == 'all' || scope == 'albums') {
      final albums = await _library.getAllLikedAlbums();
      final matches = albums
          .where(
            (a) =>
                a.name.toLowerCase().contains(query) ||
                a.artistName.toLowerCase().contains(query),
          )
          .take(12)
          .toList();
      for (final a in matches) {
        seenAlbums.putIfAbsent(
          a.albumId,
          () => AskAlbumRef(
            albumId: a.albumId,
            name: a.name,
            artist: a.artistName,
            artistId: a.artistId,
            thumbnailUrl: a.thumbnailUrl,
            year: a.year,
          ),
        );
      }
      out['albums'] = [
        for (final a in matches)
          {
            'albumId': a.albumId,
            'name': a.name,
            'artist': a.artistName,
            if (a.year != null) 'year': a.year,
          },
      ];
    }

    if (scope == 'all' || scope == 'playlists') {
      final playlists = await _library.getAllPlaylists();
      final matches = playlists
          .where((p) => p.name.toLowerCase().contains(query))
          .take(12)
          .toList();
      for (final p in matches) {
        seenLocalPlaylists.putIfAbsent(
          p.id,
          () => AskPlaylistRef(
            localPlaylistId: p.id,
            name: p.name,
            artist: p.description,
          ),
        );
      }
      out['playlists'] = [
        for (final p in matches) {'id': p.id, 'name': p.name},
      ];
    }

    if (scope == 'all' || scope == 'podcasts') {
      final podcasts = await _library.getAllLikedPodcasts();
      final matches = podcasts
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                (p.authorName?.toLowerCase().contains(query) ?? false),
          )
          .take(10)
          .toList();
      for (final p in matches) {
        seenPodcasts.putIfAbsent(
          p.browseId,
          () => AskPodcastRef(
            browseId: p.browseId,
            name: p.name,
            author: p.authorName,
            thumbnailUrl: p.thumbnailUrl,
          ),
        );
      }
      out['podcasts'] = [
        for (final p in matches)
          {
            'browseId': p.browseId,
            'name': p.name,
            if (p.authorName != null) 'author': p.authorName,
          },
      ];
    }

    return out;
  }

  Future<Map<String, dynamic>> _getLocalPlaylistTracks(
    Map<String, dynamic> args,
  ) async {
    var playlistId = (args['playlistId'] as num?)?.toInt();
    final playlistName = (args['playlistName']?.toString() ?? '').trim();
    LocalPlaylistModel? target;

    if (playlistId != null) {
      target = await _library.getPlaylist(playlistId);
    } else if (playlistName.isNotEmpty) {
      target = await _findLocalPlaylistByName(playlistName);
      playlistId = target?.id;
    }

    if (target == null || playlistId == null) {
      return {'error': 'playlist_not_found'};
    }

    seenLocalPlaylists[target.id] = AskPlaylistRef(
      localPlaylistId: target.id,
      name: target.name,
      artist: target.description,
    );

    final entries = await _library.getPlaylistEntries(playlistId);
    for (final e in entries) {
      _registerTrack(
        AskTrackRef(
          videoId: e.videoId,
          title: e.title ?? e.videoId,
          artist: e.artist ?? '',
          artistsJson: e.artistsJson,
          durationSec: e.duration,
          thumbnailUrl: e.thumbnailUrl,
          isExplicit: e.isExplicit,
          isVideo: e.isVideo,
        ),
      );
    }

    return {
      'playlistId': target.id,
      'name': target.name,
      'totalTracks': entries.length,
      'tracks': [for (final e in entries.take(80)) _trackSummary(e.videoId)],
    };
  }

  Future<Map<String, dynamic>> _getNowPlaying() async {
    final np = readNowPlaying?.call();
    if (np == null || np.videoId.isEmpty) {
      return {'playing': false};
    }
    _registerTrack(
      AskTrackRef(
        videoId: np.videoId,
        title: np.title,
        artist: np.artist,
        durationSec: np.durationSec,
      ),
    );
    return {
      'playing': true,
      'videoId': np.videoId,
      'title': np.title,
      'artist': np.artist,
      if (np.album != null) 'album': np.album,
      if (np.durationSec != null) 'durationSec': np.durationSec,
      'isEpisode': np.isEpisode,
    };
  }

  Future<Map<String, dynamic>> _searchCatalog(Map<String, dynamic> args) async {
    final query = (args['query']?.toString() ?? '').trim();
    if (query.isEmpty) return {'error': 'empty_query'};
    final type = (args['type']?.toString() ?? 'songs').trim().toLowerCase();
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 20);

    switch (type) {
      case 'artists':
        final artists = await _music.searchArtists(query, limit: limit);
        for (final a in artists) {
          seenArtists[a.artistId] = AskArtistRef(
            artistId: a.artistId,
            name: a.name,
            thumbnailUrl: a.thumbnails.isNotEmpty
                ? a.thumbnails.last.url
                : null,
            monthlyListeners: a.monthlyListeners,
          );
        }
        return {
          'artists': [
            for (final a in artists)
              {
                'artistId': a.artistId,
                'name': a.name,
                if (a.monthlyListeners != null)
                  'monthlyListeners': a.monthlyListeners,
              },
          ],
        };

      case 'albums':
        final albums = await _music.searchAlbums(query, limit: limit);
        for (final a in albums) {
          seenAlbums[a.albumId] = AskAlbumRef(
            albumId: a.albumId,
            name: a.name,
            artist: displayArtists(a.artists),
            artistId: primaryArtistId(a.artists),
            thumbnailUrl: a.thumbnails.isNotEmpty
                ? a.thumbnails.last.url
                : null,
            year: a.year,
          );
        }
        return {
          'albums': [
            for (final a in albums)
              {
                'albumId': a.albumId,
                'name': a.name,
                'artist': displayArtists(a.artists),
                if (a.year != null) 'year': a.year,
              },
          ],
        };

      case 'playlists':
        final playlists = await _music.searchPlaylists(query, limit: limit);
        for (final p in playlists) {
          seenPlaylists[p.playlistId] = AskPlaylistRef(
            playlistId: p.playlistId,
            name: p.name,
            artist: displayArtists(p.artists),
            thumbnailUrl: p.thumbnails.isNotEmpty
                ? p.thumbnails.last.url
                : null,
          );
        }
        return {
          'playlists': [
            for (final p in playlists)
              {
                'playlistId': p.playlistId,
                'name': p.name,
                'creator': displayArtists(p.artists),
              },
          ],
        };

      case 'podcasts':
        final podcasts = await _music.searchPodcasts(query, limit: limit);
        for (final p in podcasts) {
          seenPodcasts[p.browseId] = AskPodcastRef(
            browseId: p.browseId,
            name: p.name,
            author: p.author,
            thumbnailUrl: p.thumbnails.isNotEmpty
                ? p.thumbnails.last.url
                : null,
          );
        }
        return {
          'podcasts': [
            for (final p in podcasts)
              {
                'browseId': p.browseId,
                'name': p.name,
                if (p.author != null) 'author': p.author,
              },
          ],
        };

      case 'episodes':
        final episodes = await _music.searchEpisodes(query, limit: limit);
        for (final e in episodes) {
          seenEpisodes[e.videoId] = AskEpisodeRef(
            videoId: e.videoId,
            name: e.name,
            podcastName: e.podcastName,
            podcastBrowseId: e.podcastId,
            thumbnailUrl: e.thumbnails.isNotEmpty
                ? e.thumbnails.last.url
                : null,
            date: e.date,
          );
        }
        return {
          'episodes': [
            for (final e in episodes)
              {
                'videoId': e.videoId,
                'name': e.name,
                if (e.podcastName != null) 'podcast': e.podcastName,
                if (e.date != null) 'date': e.date,
              },
          ],
        };

      case 'songs':
      default:
        final songs = await _music.searchSongs(query, limit: limit);
        final out = <Map<String, dynamic>>[];
        for (final s in songs) {
          if (s.videoId.isEmpty || !s.isPlayable) continue;
          _registerSongDetailed(s);
          out.add(_trackSummary(s.videoId));
        }
        return {'songs': out};
    }
  }

  Future<Map<String, dynamic>> _getArtistInfo(Map<String, dynamic> args) async {
    var artistId = (args['artistId']?.toString() ?? '').trim();
    final artistName = (args['artistName']?.toString() ?? '').trim();
    if (artistId.isEmpty && artistName.isNotEmpty) {
      final found = await _music.searchArtists(artistName, limit: 3);
      if (found.isNotEmpty) {
        artistId = found.first.artistId;
      }
    }
    if (artistId.isEmpty) return {'error': 'missing_artist_id'};

    final artist = await _music.getArtist(artistId);
    seenArtists[artist.artistId] = AskArtistRef(
      artistId: artist.artistId,
      name: artist.name,
      thumbnailUrl: artist.thumbnails.isNotEmpty
          ? artist.thumbnails.last.url
          : null,
      monthlyListeners: artist.monthlyListeners,
    );

    final topSongsOut = <Map<String, dynamic>>[];
    for (final s in artist.topSongs.take(10)) {
      if (s.videoId.isEmpty || !s.isPlayable) continue;
      _registerSongDetailed(s);
      topSongsOut.add(_trackSummary(s.videoId));
    }
    for (final al in artist.topAlbums.take(12)) {
      seenAlbums[al.albumId] = AskAlbumRef(
        albumId: al.albumId,
        name: al.name,
        artist: displayArtists(al.artists).isNotEmpty
            ? displayArtists(al.artists)
            : artist.name,
        artistId: primaryArtistId(al.artists) ?? artist.artistId,
        thumbnailUrl: al.thumbnails.isNotEmpty ? al.thumbnails.last.url : null,
        year: al.year,
      );
    }
    final similarOut = <Map<String, dynamic>>[];
    for (final sim in artist.similarArtists.take(8)) {
      seenArtists[sim.artistId] = AskArtistRef(
        artistId: sim.artistId,
        name: sim.name,
        thumbnailUrl: sim.thumbnails.isNotEmpty
            ? sim.thumbnails.last.url
            : null,
      );
      similarOut.add({'artistId': sim.artistId, 'name': sim.name});
    }

    return {
      'artistId': artist.artistId,
      'name': artist.name,
      if (artist.monthlyListeners != null)
        'monthlyListeners': artist.monthlyListeners,
      if (artist.description != null && artist.description!.isNotEmpty)
        'description': artist.description!.length > 400
            ? artist.description!.substring(0, 400)
            : artist.description,
      'topSongs': topSongsOut,
      'topAlbums': [
        for (final al in artist.topAlbums.take(6))
          {'albumId': al.albumId, 'name': al.name, 'year': al.year},
      ],
      'similarArtists': similarOut,
    };
  }

  Future<Map<String, dynamic>> _getSongRelated(
    Map<String, dynamic> args,
  ) async {
    final videoId = (args['videoId']?.toString() ?? '').trim();
    if (videoId.isEmpty) return {'error': 'missing_video_id'};
    final limit = ((args['limit'] as num?)?.toInt() ?? 15).clamp(1, 30);

    final watch = await _music.getWatchPlaylist(videoId: videoId, radio: true);
    final out = <Map<String, dynamic>>[];
    for (final t in watch.tracks.take(limit)) {
      if (t.videoId.isEmpty) continue;
      _registerTrack(
        AskTrackRef(
          videoId: t.videoId,
          title: t.title,
          artist: displayArtists(t.artists),
          artistsJson: encodeArtistsJson(t.artists),
          durationSec: t.duration,
          thumbnailUrl: t.thumbnails.isNotEmpty ? t.thumbnails.last.url : null,
          isExplicit: t.isExplicit,
        ),
      );
      out.add(_trackSummary(t.videoId));
    }

    final relatedArtists = <Map<String, dynamic>>[];
    final relatedId = watch.relatedBrowseId;
    if (relatedId != null && relatedId.isNotEmpty) {
      try {
        final sections = await _music.getSongRelated(relatedId);
        for (final sec in sections) {
          for (final item in sec.contents.take(8)) {
            if (item is SongDetailed &&
                item.videoId.isNotEmpty &&
                item.isPlayable) {
              _registerSongDetailed(item);
            } else if (item is ArtistDetailed) {
              seenArtists[item.artistId] = AskArtistRef(
                artistId: item.artistId,
                name: item.name,
                thumbnailUrl: item.thumbnails.isNotEmpty
                    ? item.thumbnails.last.url
                    : null,
              );
              relatedArtists.add({
                'artistId': item.artistId,
                'name': item.name,
              });
            }
          }
        }
      } catch (_) {
        // Radio queue tracks are sufficient if related browse fails.
      }
    }

    return {
      'tracks': out,
      if (relatedArtists.isNotEmpty) 'relatedArtists': relatedArtists,
    };
  }

  Future<Map<String, dynamic>> _getAlbumOrPlaylist(
    Map<String, dynamic> args,
  ) async {
    final id = (args['id']?.toString() ?? '').trim();
    final kind = (args['kind']?.toString() ?? 'album').trim().toLowerCase();
    if (id.isEmpty) return {'error': 'missing_id'};

    if (kind == 'album') {
      final album = await _music.getAlbum(id);
      seenAlbums[album.albumId] = AskAlbumRef(
        albumId: album.albumId,
        name: album.name,
        artist: displayArtists(album.artists),
        artistId: primaryArtistId(album.artists),
        thumbnailUrl: album.thumbnails.isNotEmpty
            ? album.thumbnails.last.url
            : null,
        year: album.year,
      );
      final out = <Map<String, dynamic>>[];
      for (final s in album.songs.take(50)) {
        if (s.videoId.isEmpty || !s.isPlayable) continue;
        _registerSongDetailed(s);
        out.add(_trackSummary(s.videoId));
      }
      return {
        'albumId': album.albumId,
        'name': album.name,
        'artist': displayArtists(album.artists),
        if (album.year != null) 'year': album.year,
        'tracks': out,
      };
    } else {
      final playlist = await _music.getPlaylist(id, limit: 60);
      seenPlaylists[playlist.playlistId] = AskPlaylistRef(
        playlistId: playlist.playlistId,
        name: playlist.name,
        artist: displayArtists(playlist.artists),
        thumbnailUrl: playlist.thumbnails.isNotEmpty
            ? playlist.thumbnails.last.url
            : null,
      );
      final out = <Map<String, dynamic>>[];
      for (final v in playlist.tracks.take(50)) {
        if (v.videoId.isEmpty || !v.isPlayable) continue;
        _registerVideoDetailed(v);
        out.add(_trackSummary(v.videoId));
      }
      return {
        'playlistId': playlist.playlistId,
        'name': playlist.name,
        'tracks': out,
      };
    }
  }

  Future<Map<String, dynamic>> _getChartsOrMoods(
    Map<String, dynamic> args,
  ) async {
    final kind = (args['kind']?.toString() ?? 'charts').trim().toLowerCase();
    final country = (args['country']?.toString() ?? 'ZZ').trim().toUpperCase();

    if (kind == 'moods') {
      final moods = await _music.getMoodCategories();
      return {
        'sections': {
          for (final entry in moods.sections.entries.take(6))
            entry.key: [
              for (final m in entry.value.take(10))
                {'title': m.title, 'params': m.params},
            ],
        },
      };
    }

    final charts = await _music.getCharts(
      country: country.isEmpty ? 'ZZ' : country,
    );
    for (final a in charts.artists.take(12)) {
      if (a.browseId.isEmpty) continue;
      seenArtists[a.browseId] = AskArtistRef(
        artistId: a.browseId,
        name: a.title,
        thumbnailUrl: a.thumbnails.isNotEmpty ? a.thumbnails.last.url : null,
      );
    }
    for (final p in [...?charts.daily, ...?charts.weekly].take(8)) {
      if (p.playlistId.isEmpty) continue;
      seenPlaylists[p.playlistId] = AskPlaylistRef(
        playlistId: p.playlistId,
        name: p.title,
        thumbnailUrl: p.thumbnails.isNotEmpty ? p.thumbnails.last.url : null,
      );
    }
    return {
      'country': charts.countries.selected,
      'topArtists': [
        for (final a in charts.artists.take(12))
          {'browseId': a.browseId, 'name': a.title, 'rank': a.rank},
      ],
      'playlists': [
        for (final p in [...?charts.daily, ...?charts.weekly].take(8))
          {'playlistId': p.playlistId, 'title': p.title},
      ],
    };
  }

  Future<Map<String, dynamic>> _getSongLyrics(Map<String, dynamic> args) async {
    final videoId = (args['videoId']?.toString() ?? '').trim();
    if (videoId.isEmpty) return {'error': 'missing_video_id'};
    final lyrics = await _music.getLyrics(videoId);
    if (lyrics == null || lyrics.trim().isEmpty) {
      return {'found': false};
    }
    final trimmed = lyrics.trim();
    return {
      'found': true,
      'lyrics': trimmed.length > 3000 ? trimmed.substring(0, 3000) : trimmed,
    };
  }

  Map<String, dynamic> _proposeMix(Map<String, dynamic> args) {
    final title = (args['title']?.toString() ?? '').trim();
    final subtitle = (args['subtitle']?.toString() ?? '').trim();
    final rawIds = args['videoIds'];
    if (rawIds is! List) return {'error': 'invalid_video_ids'};

    final verified = <AskTrackRef>[];
    final rejected = <String>[];
    final dedup = <String>{};
    for (final rawId in rawIds) {
      final id = rawId.toString().trim();
      if (id.isEmpty || !dedup.add(id)) continue;
      final track = seenTracks[id];
      if (track == null) {
        rejected.add(id);
      } else {
        verified.add(track);
      }
    }

    if (verified.isEmpty) {
      return {
        'ok': false,
        'error': 'no_verified_tracks_in_turn',
        'rejectedCount': rejected.length,
      };
    }

    attachments.add(
      AskMixAttachment(
        title: title.isEmpty ? 'Sonora Ask Mix' : title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        tracks: verified,
      ),
    );
    return {
      'ok': true,
      'attachedTracks': verified.length,
      'rejectedCount': rejected.length,
    };
  }

  Future<Map<String, dynamic>> _proposePlaylistWrite(
    Map<String, dynamic> args,
  ) async {
    final rawOp = (args['operation']?.toString() ?? 'create')
        .trim()
        .toLowerCase();
    final operation = (rawOp == 'append' || rawOp == 'remove')
        ? rawOp
        : 'create';
    var playlistName = (args['playlistName']?.toString() ?? '').trim();
    var targetPlaylistId = (args['targetPlaylistId'] as num?)?.toInt();
    final rawIds = args['videoIds'];
    if (rawIds is! List) return {'error': 'invalid_video_ids'};

    if (targetPlaylistId == null &&
        (operation == 'append' || operation == 'remove') &&
        playlistName.isNotEmpty) {
      final matched = await _findLocalPlaylistByName(playlistName);
      if (matched != null) {
        targetPlaylistId = matched.id;
        playlistName = matched.name;
      }
    }

    // For remove/append against an existing playlist, seed seenTracks and
    // track existing videoIds so append proposals automatically deduplicate.
    final existingIds = <String>{};
    if (targetPlaylistId != null) {
      final entries = await _library.getPlaylistEntries(targetPlaylistId);
      for (final e in entries) {
        existingIds.add(e.videoId);
        _registerTrack(
          AskTrackRef(
            videoId: e.videoId,
            title: e.title ?? e.videoId,
            artist: e.artist ?? '',
            artistsJson: e.artistsJson,
            durationSec: e.duration,
            thumbnailUrl: e.thumbnailUrl,
            isExplicit: e.isExplicit,
            isVideo: e.isVideo,
          ),
        );
      }
    }

    final verified = <AskTrackRef>[];
    final rejected = <String>[];
    var skippedAlreadyInPlaylist = 0;
    final dedup = <String>{};
    for (final rawId in rawIds) {
      final id = rawId.toString().trim();
      if (id.isEmpty || !dedup.add(id)) continue;
      final track = seenTracks[id];
      if (track == null) {
        rejected.add(id);
      } else if (operation == 'append' && existingIds.contains(id)) {
        skippedAlreadyInPlaylist++;
      } else {
        verified.add(track);
      }
    }

    if (verified.isEmpty) {
      return {
        'ok': false,
        'error': skippedAlreadyInPlaylist > 0
            ? 'all_tracks_already_in_playlist'
            : 'no_verified_tracks_in_turn',
        if (targetPlaylistId != null) 'existingCount': existingIds.length,
        if (skippedAlreadyInPlaylist > 0)
          'skippedAlreadyInPlaylist': skippedAlreadyInPlaylist,
        'rejectedCount': rejected.length,
      };
    }

    attachments.add(
      AskPlaylistWriteProposal(
        operation: operation,
        targetPlaylistId: targetPlaylistId,
        playlistName: playlistName.isEmpty ? 'Sonora Playlist' : playlistName,
        tracks: verified,
        status: 'pending',
      ),
    );
    return {
      'ok': true,
      'awaitingUserConfirmation': true,
      if (targetPlaylistId != null) 'existingCount': existingIds.length,
      'trackCount': verified.length,
      'resultingTotalTracks': operation == 'append'
          ? existingIds.length + verified.length
          : verified.length,
      if (skippedAlreadyInPlaylist > 0)
        'skippedAlreadyInPlaylist': skippedAlreadyInPlaylist,
      'rejectedCount': rejected.length,
    };
  }

  Map<String, dynamic> _presentCatalogItems(Map<String, dynamic> args) {
    final title = (args['title']?.toString() ?? '').trim();
    var rejectedCount = 0;

    List<T> collectString<T>(Object? rawList, Map<String, T> registry) {
      if (rawList is! List) return const [];
      final out = <T>[];
      final seen = <String>{};
      for (final raw in rawList) {
        final id = raw.toString().trim();
        if (id.isEmpty || !seen.add(id)) continue;
        final item = registry[id];
        if (item == null) {
          rejectedCount++;
        } else {
          out.add(item);
        }
      }
      return out;
    }

    final artists = collectString(args['artistIds'], seenArtists);
    final tracks = collectString(args['trackVideoIds'], seenTracks);
    final albums = collectString(args['albumIds'], seenAlbums);
    final playlists = <AskPlaylistRef>[
      ...collectString(args['playlistIds'], seenPlaylists),
    ];
    final rawLocalPlaylistIds = args['localPlaylistIds'];
    if (rawLocalPlaylistIds is List) {
      final seenLocal = <int>{};
      for (final raw in rawLocalPlaylistIds) {
        final id =
            (raw as num?)?.toInt() ?? int.tryParse(raw.toString().trim());
        if (id == null || !seenLocal.add(id)) continue;
        final item = seenLocalPlaylists[id];
        if (item == null) {
          rejectedCount++;
        } else {
          playlists.add(item);
        }
      }
    }
    final podcasts = collectString(args['podcastBrowseIds'], seenPodcasts);
    final episodes = collectString(args['episodeVideoIds'], seenEpisodes);

    if (artists.isNotEmpty) {
      attachments.add(AskArtistsAttachment(title: title, artists: artists));
    }
    if (tracks.isNotEmpty) {
      attachments.add(AskTracksAttachment(title: title, tracks: tracks));
    }
    if (albums.isNotEmpty) {
      attachments.add(AskAlbumsAttachment(title: title, albums: albums));
    }
    if (playlists.isNotEmpty) {
      attachments.add(
        AskPlaylistsAttachment(title: title, playlists: playlists),
      );
    }
    if (podcasts.isNotEmpty) {
      attachments.add(AskPodcastsAttachment(title: title, podcasts: podcasts));
    }
    if (episodes.isNotEmpty) {
      attachments.add(AskEpisodesAttachment(title: title, episodes: episodes));
    }

    final attachedTotal =
        artists.length +
        tracks.length +
        albums.length +
        playlists.length +
        podcasts.length +
        episodes.length;

    return {
      'ok': attachedTotal > 0,
      'attached': {
        'artists': artists.length,
        'tracks': tracks.length,
        'albums': albums.length,
        'playlists': playlists.length,
        'podcasts': podcasts.length,
        'episodes': episodes.length,
      },
      'rejectedCount': rejectedCount,
    };
  }

  Future<LocalPlaylistModel?> _findLocalPlaylistByName(String rawName) async {
    final lower = rawName.trim().toLowerCase();
    if (lower.isEmpty) return null;
    final all = await _library.getAllPlaylists();
    for (final p in all) {
      if (p.name.trim().toLowerCase() == lower) return p;
    }
    for (final p in all) {
      if (p.name.toLowerCase().contains(lower)) return p;
    }
    return null;
  }

  void _registerSongDetailed(SongDetailed s) {
    _registerTrack(
      AskTrackRef(
        videoId: s.videoId,
        title: s.name,
        artist: displayArtists(s.artists),
        artistsJson: encodeArtistsJson(s.artists),
        artistId: primaryArtistId(s.artists),
        albumId: s.album?.albumId,
        albumName: s.album?.name,
        durationSec: s.duration,
        thumbnailUrl: s.thumbnails.isNotEmpty ? s.thumbnails.last.url : null,
        isExplicit: s.isExplicit,
        isVideo: s.type == 'VIDEO',
      ),
    );
  }

  void _registerVideoDetailed(VideoDetailed v) {
    _registerTrack(
      AskTrackRef(
        videoId: v.videoId,
        title: v.name,
        artist: displayArtists(v.artists),
        artistsJson: encodeArtistsJson(v.artists),
        artistId: primaryArtistId(v.artists),
        durationSec: v.duration,
        thumbnailUrl: v.thumbnails.isNotEmpty ? v.thumbnails.last.url : null,
        isExplicit: v.isExplicit,
        isVideo: true,
      ),
    );
  }

  void _registerTrack(AskTrackRef track) {
    if (track.videoId.isEmpty) return;
    seenTracks[track.videoId] = track;
  }

  Map<String, dynamic> _trackSummary(String videoId) {
    final t = seenTracks[videoId];
    if (t == null) return {'videoId': videoId};
    return {
      'videoId': t.videoId,
      'title': t.title,
      'artist': t.artist,
      if (t.durationSec != null) 'durationSec': t.durationSec,
    };
  }
}
