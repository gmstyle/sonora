import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';

import '../../../../core/utils/playable_tracks.dart';
import '../../../../domain/models/ask_chat_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/repositories/llm_completion_repository.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../domain/usecases/player/play_album_use_case.dart';
import '../../../../domain/usecases/player/play_local_playlist_use_case.dart';
import '../../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../../domain/usecases/player/play_podcast_use_case.dart';
import '../../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../../domain/usecases/player/start_radio_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import 'aa_content_mapper.dart';
import 'aa_content_styles.dart';
import 'aa_downloads_builder.dart';
import 'aa_media_id.dart';

const String _kAaMixIntentSystemInstruction = '''
Convert a natural-language music mood request into JSON:
{"title":"string","searchQuery":"string","seedArtists":["string"]}
Rules: searchQuery must be concise English keywords for YouTube Music search. Never invent IDs.
''';

/// Handles Android Auto text search (offline local + online catalog incl. podcasts)
/// and structured Google Assistant voice queries (`playFromSearch`).
class AaSearchController {
  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final PlayAlbumUseCase _playAlbumUseCase;
  final PlayPlaylistUseCase _playPlaylistUseCase;
  final PlayPodcastUseCase _playPodcastUseCase;
  final PlayLocalPlaylistUseCase _playLocalPlaylistUseCase;
  final StartRadioUseCase _startRadioUseCase;
  final AaDownloadsBuilder _downloadsBuilder;
  final LlmCompletionRepository? _llmCompletionRepo;
  final Future<void> Function() _resumePlayback;
  final Future<void> Function(List<MediaItem> items, {int initialIndex})
  _playNow;

  AaSearchController({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required this._downloadsBuilder,
    this._llmCompletionRepo,
    required this._resumePlayback,
    required this._playNow,
  }) : _musicRepo = musicRepo,
       _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase,
       _playAlbumUseCase = PlayAlbumUseCase(playVideoIdUseCase),
       _playPlaylistUseCase = PlayPlaylistUseCase(playVideoIdUseCase),
       _playPodcastUseCase = PlayPodcastUseCase(playVideoIdUseCase),
       _playLocalPlaylistUseCase = PlayLocalPlaylistUseCase(
         playVideoIdUseCase,
         libraryRepo,
       ),
       _startRadioUseCase = StartRadioUseCase(musicRepo, playVideoIdUseCase);

  Future<List<MediaItem>> search(
    String query, {
    required bool isOffline,
    required AppLocalizations l10n,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final localItems = await _searchLocal(trimmed, l10n);
    if (isOffline) return localItems;

    try {
      final (songs, artists, albums, playlists, podcasts, episodes) = await (
        _safeList(() => _musicRepo.searchSongs(trimmed)),
        _safeList(() => _musicRepo.searchArtists(trimmed)),
        _safeList(() => _musicRepo.searchAlbums(trimmed)),
        _safeList(() => _musicRepo.searchPlaylists(trimmed)),
        _safeList(() => _musicRepo.searchPodcasts(trimmed)),
        _safeList(() => _musicRepo.searchEpisodes(trimmed)),
      ).wait;

      final songItems = playableSongs(songs)
          .map(
            (s) => AaContentMapper.songToMediaItem(s, groupTitle: l10n.songs),
          )
          .toList(growable: false);
      final artistItems = artists
          .map(
            (a) =>
                AaContentMapper.artistToBrowseItem(a, groupTitle: l10n.artists),
          )
          .toList(growable: false);
      final albumItems = albums
          .map(
            (a) =>
                AaContentMapper.albumToBrowseItem(a, groupTitle: l10n.albums),
          )
          .toList(growable: false);
      final playlistItems = playlists
          .map(
            (p) => AaContentMapper.playlistToBrowseItem(
              p,
              groupTitle: l10n.playlists,
            ),
          )
          .toList(growable: false);
      final podcastItems = podcasts
          .where((p) => p.browseId.isNotEmpty)
          .map(
            (p) => AaContentMapper.podcastToBrowseItem(
              p,
              groupTitle: l10n.podcasts,
            ),
          )
          .toList(growable: false);
      final episodeItems = episodes
          .map(
            (e) => AaContentMapper.episodeToMediaItem(
              e,
              groupTitle: l10n.episodes,
            ),
          )
          .whereType<MediaItem>()
          .toList(growable: false);

      return [
        ...localItems,
        ...songItems,
        ...artistItems,
        ...albumItems,
        ...playlistItems,
        ...podcastItems,
        ...episodeItems,
      ];
    } catch (_) {
      return localItems;
    }
  }

  Future<List<MediaItem>> _searchLocal(
    String query,
    AppLocalizations l10n,
  ) async {
    final q = query.toLowerCase();
    final (downloads, likedSongs, playlists, podcasts) = await (
      _downloadsBuilder.getCompletedDownloads(),
      _libraryRepo.getAllLikedSongs(),
      _libraryRepo.getAllPlaylists(),
      _libraryRepo.getAllLikedPodcasts(),
    ).wait;

    final items = <MediaItem>[];
    final seenVideoIds = <String>{};

    for (var i = 0; i < downloads.length; i++) {
      final d = downloads[i];
      if (d.title.toLowerCase().contains(q) ||
          d.artist.toLowerCase().contains(q) ||
          (d.collectionName?.toLowerCase().contains(q) ?? false)) {
        if (seenVideoIds.add(d.videoId)) {
          items.add(
            AaContentMapper.downloadToMediaItem(
              d,
              index: i,
              groupKey: d.collectionId != null && d.collectionType != null
                  ? '${d.collectionType}:${d.collectionId}'
                  : 'singles',
              groupTitle: l10n.aaLocalLibraryMatches,
            ),
          );
        }
      }
      if (items.length >= 6) break;
    }

    for (var i = 0; i < likedSongs.length; i++) {
      final s = likedSongs[i];
      if (s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q)) {
        if (seenVideoIds.add(s.videoId)) {
          items.add(
            AaContentMapper.likedSongToMediaItem(
              s,
              index: i,
              groupTitle: l10n.aaLocalLibraryMatches,
            ),
          );
        }
      }
      if (items.length >= 10) break;
    }

    for (final p in playlists) {
      if (p.name.toLowerCase().contains(q)) {
        items.add(
          MediaItem(
            id: AaMediaId.localPlaylist(p.id),
            title: p.name,
            displaySubtitle: l10n.aaLocalPlaylistSubtitle,
            artUri: AaContentStyles.drawableUri('cover_playlist'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.aaLocalLibraryMatches,
            ),
          ),
        );
      }
    }

    for (final pod in podcasts) {
      if (pod.name.toLowerCase().contains(q) ||
          (pod.authorName?.toLowerCase().contains(q) ?? false)) {
        items.add(
          MediaItem(
            id: AaMediaId.podcast(pod.browseId),
            title: pod.name,
            artist: pod.authorName,
            artUri: pod.thumbnailUrl != null
                ? Uri.tryParse(pod.thumbnailUrl!)
                : AaContentStyles.drawableUri('cover_podcasts'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.aaLocalLibraryMatches,
            ),
          ),
        );
      }
    }

    return items;
  }

  Future<void> playFromSearch(
    String query, {
    Map<String, dynamic>? extras,
    required bool isOffline,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await _resumePlayback();
      return;
    }

    if (isOffline) {
      await _playFromOfflineDownloads(trimmed);
      return;
    }

    final focus = extras?['android.intent.extra.focus']?.toString();
    switch (focus) {
      case 'vnd.android.cursor.item/artist':
        final artistQuery =
            extras?['android.intent.extra.artist']?.toString().trim() ?? '';
        if (await _playArtistByQuery(
          artistQuery.isNotEmpty ? artistQuery : trimmed,
        )) {
          return;
        }
      case 'vnd.android.cursor.item/album':
        final albumQuery =
            extras?['android.intent.extra.album']?.toString().trim() ?? '';
        if (await _playAlbumByQuery(
          albumQuery.isNotEmpty ? albumQuery : trimmed,
        )) {
          return;
        }
      case 'vnd.android.cursor.item/playlist':
        if (await _playPlaylistByQuery(trimmed)) return;
      case 'vnd.android.cursor.item/podcast':
        if (await _playPodcastByQuery(trimmed)) return;
      case 'vnd.android.cursor.item/genre':
        final genreQuery =
            extras?['android.intent.extra.genre']?.toString().trim() ?? '';
        if (await _playPlaylistByQuery(
          genreQuery.isNotEmpty ? genreQuery : trimmed,
        )) {
          return;
        }
    }

    // Hybrid Sonora Ask voice mix for descriptive requests without explicit focus.
    if ((focus == null || focus.isEmpty) &&
        trimmed.split(RegExp(r'\s+')).length >= 4) {
      if (await _tryPlayAskMixIntent(trimmed)) return;
    }

    // Default unstructured song search.
    final results = playableSongs(await _musicRepo.searchSongs(trimmed));
    if (results.isEmpty) {
      await _playFromOfflineDownloads(trimmed);
      return;
    }
    final firstItem = await _playVideoIdUseCase.execute(results.first.videoId);
    final remaining = results
        .skip(1)
        .map(AaContentMapper.songToMediaItem)
        .toList(growable: false);
    await _playNow([firstItem, ...remaining]);
  }

  Future<void> _playFromOfflineDownloads(String query) async {
    final q = query.toLowerCase();
    final downloads = await _downloadsBuilder.getCompletedDownloads();
    if (downloads.isEmpty) return;

    final matches = downloads
        .where(
          (d) =>
              d.title.toLowerCase().contains(q) ||
              d.artist.toLowerCase().contains(q) ||
              (d.collectionName?.toLowerCase().contains(q) ?? false),
        )
        .toList(growable: false);
    final selected = matches.isNotEmpty ? matches : downloads;
    final items = <MediaItem>[];
    for (var i = 0; i < selected.length; i++) {
      items.add(
        AaContentMapper.downloadToMediaItem(
          selected[i],
          index: i,
          groupKey: 'search',
        ),
      );
    }
    final firstUrl = await _playVideoIdUseCase.resolveUrl(
      selected.first.videoId,
    );
    final firstTrack = QueueTrack.fromMediaItem(items.first)
        .copyWith(url: firstUrl, needsUrl: false);
    items[0] = firstTrack.toMediaItem(items.first);
    await _playNow(items);
  }

  Future<bool> _playArtistByQuery(String query) async {
    final artists = await _musicRepo.searchArtists(query);
    if (artists.isEmpty) return false;
    final artistId = artists.first.artistId;
    var songs = playableSongs(await _musicRepo.getArtistSongs(artistId));
    if (songs.isEmpty) {
      songs = playableSongs((await _musicRepo.getArtist(artistId)).topSongs);
    }
    if (songs.isEmpty) return false;
    final items = await _playAlbumUseCase.execute(songs);
    if (items.isEmpty) return false;
    await _playNow(items);
    return true;
  }

  Future<bool> _playAlbumByQuery(String query) async {
    final albums = await _musicRepo.searchAlbums(query);
    if (albums.isEmpty) return false;
    final albumId = await _musicRepo.resolveAlbumId(albums.first.albumId);
    final album = await _musicRepo.getAlbum(albumId);
    final items = await _playAlbumUseCase.execute(album.songs);
    if (items.isEmpty) return false;
    await _playNow(items);
    return true;
  }

  Future<bool> _playPlaylistByQuery(String query) async {
    final q = query.toLowerCase();
    final localPlaylists = await _libraryRepo.getAllPlaylists();
    for (final local in localPlaylists) {
      if (local.name.toLowerCase().contains(q)) {
        final entries = await _libraryRepo.getPlaylistEntries(local.id);
        final items = await _playLocalPlaylistUseCase.execute(entries);
        if (items.isNotEmpty) {
          await _playNow(items);
          return true;
        }
      }
    }

    final remote = await _musicRepo.searchPlaylists(query);
    if (remote.isEmpty) return false;
    final videos = await _musicRepo.getPlaylistVideos(remote.first.playlistId);
    final items = await _playPlaylistUseCase.execute(videos);
    if (items.isEmpty) return false;
    await _playNow(items);
    return true;
  }

  Future<bool> _playPodcastByQuery(String query) async {
    final podcasts = await _musicRepo.searchPodcasts(query);
    final valid = podcasts
        .where((p) => p.browseId.isNotEmpty)
        .toList(growable: false);
    if (valid.isEmpty) return false;
    final full = await _musicRepo.getPodcast(valid.first.browseId, limit: 100);
    final items = await _playPodcastUseCase.execute(
      full.episodes,
      podcastBrowseId: valid.first.browseId,
      podcastName: full.name,
      authorName: full.author?.name,
      authorId: full.author?.artistId,
    );
    if (items.isEmpty) return false;
    await _playNow(items);
    return true;
  }

  Future<bool> _tryPlayAskMixIntent(String query) async {
    final llm = _llmCompletionRepo;
    if (llm == null) return false;
    try {
      if (!await llm.isReady()) return false;
      final locale = PlatformDispatcher.instance.locale.languageCode;
      final raw = await llm
          .complete(
            action: AskActionKind.mixIntent,
            systemInstruction: _kAaMixIntentSystemInstruction,
            userMessage: query,
            maxOutputTokens: 256,
            locale: locale,
          )
          .timeout(const Duration(seconds: 6));

      final searchQuery = _extractMixSearchQuery(raw);
      if (searchQuery == null || searchQuery.isEmpty) return false;

      final songs = playableSongs(await _musicRepo.searchSongs(searchQuery));
      if (songs.isEmpty) return false;

      final seedId = songs.first.videoId;
      try {
        final radio = await _startRadioUseCase.execute(seedId);
        final remaining = _startRadioUseCase.toPendingItems(radio.remaining);
        await _playNow([radio.firstItem, ...remaining]);
        return true;
      } catch (_) {
        final items = await _playAlbumUseCase.execute(songs);
        if (items.isEmpty) return false;
        await _playNow(items);
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  static String? _extractMixSearchQuery(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('```')) {
      clean = clean
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    try {
      final decoded = jsonDecode(clean);
      if (decoded is Map) {
        final q = decoded['searchQuery']?.toString().trim();
        if (q != null && q.isNotEmpty) return q;
        final artists = decoded['seedArtists'];
        if (artists is List && artists.isNotEmpty) {
          return artists.first.toString().trim();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<T>> _safeList<T>(Future<List<T>> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return const [];
    }
  }
}
