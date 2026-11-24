import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../core/utils/playable_tracks.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../domain/repositories/ask_storage_repository.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../domain/usecases/player/play_album_use_case.dart';
import '../../../../domain/usecases/player/play_local_playlist_use_case.dart';
import '../../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../../domain/usecases/player/play_podcast_use_case.dart';
import '../../../../domain/usecases/player/play_smart_mix_use_case.dart';
import '../../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../../domain/usecases/player/start_radio_use_case.dart';
import 'aa_content_mapper.dart';
import 'aa_downloads_builder.dart';
import 'aa_home_builder.dart';
import 'aa_library_builder.dart';
import 'aa_media_id.dart';

/// Dispatches Android Auto `playFromMediaId` requests with contextual collection
/// support (`initialIndex` preserved) and rapid-tap cancellation (`shouldAbort`).
class AaPlaybackDispatcher {
  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final PlayAlbumUseCase _playAlbumUseCase;
  final PlayPlaylistUseCase _playPlaylistUseCase;
  final PlayPodcastUseCase _playPodcastUseCase;
  final PlaySmartMixUseCase _playSmartMixUseCase;
  final PlayLocalPlaylistUseCase _playLocalPlaylistUseCase;
  final StartRadioUseCase _startRadioUseCase;
  final AaHomeBuilder _homeBuilder;
  final AaLibraryBuilder _libraryBuilder;
  final AaDownloadsBuilder _downloadsBuilder;
  final AskStorageRepository? _askStorageRepo;
  final Future<void> Function(
    List<MediaItem> items, {
    int initialIndex,
    bool Function()? shouldAbort,
  })
  _playNow;
  final Future<void> Function(String query, Map<String, dynamic>? extras)
  _playFromSearch;

  int _operationVersion = 0;

  AaPlaybackDispatcher({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required this._homeBuilder,
    required this._libraryBuilder,
    required this._downloadsBuilder,
    this._askStorageRepo,
    required this._playNow,
    required this._playFromSearch,
  }) : _musicRepo = musicRepo,
       _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase,
       _playAlbumUseCase = PlayAlbumUseCase(playVideoIdUseCase),
       _playPlaylistUseCase = PlayPlaylistUseCase(playVideoIdUseCase),
       _playPodcastUseCase = PlayPodcastUseCase(playVideoIdUseCase),
       _playSmartMixUseCase = PlaySmartMixUseCase(playVideoIdUseCase),
       _playLocalPlaylistUseCase = PlayLocalPlaylistUseCase(
         playVideoIdUseCase,
         libraryRepo,
       ),
       _startRadioUseCase = StartRadioUseCase(musicRepo, playVideoIdUseCase);

  Future<void> playFromMediaId(String mediaId) async {
    final target = AaMediaId.tryParsePlayTrack(mediaId);
    if (target != null) {
      await _playContextualTrack(target);
      return;
    }

    final action = AaMediaId.tryParseAction(mediaId);
    if (action != null) {
      await _handleAction(action);
      return;
    }

    // Fallback: direct videoId (e.g. EXTRA_RECENT or standalone search track).
    final v = ++_operationVersion;
    final item = await _playVideoIdUseCase.execute(mediaId);
    if (_operationVersion != v) return;
    await _playNow([item], shouldAbort: () => _operationVersion != v);
  }

  int _resolveIndex<T>(
    List<T> items,
    String Function(T item) idOf,
    AaPlayTarget target,
  ) {
    if (target.videoId.isNotEmpty) {
      final byId = items.indexWhere((e) => idOf(e) == target.videoId);
      if (byId >= 0) return byId;
    }
    return target.index.clamp(0, items.length - 1);
  }

  Future<void> _playContextualTrack(AaPlayTarget target) async {
    final v = ++_operationVersion;
    bool aborted() => _operationVersion != v;

    switch (target.contextKind) {
      case AaMediaId.ctxAlbum:
        final albumId = await _musicRepo.resolveAlbumId(target.contextId);
        if (aborted()) return;
        final album = await _musicRepo.getAlbum(albumId);
        if (aborted()) return;
        final songs = playableSongs(album.songs)
            .take(100)
            .toList(growable: false);
        if (songs.isEmpty) return;
        final idx = _resolveIndex(songs, (s) => s.videoId, target);
        var leadIndex = idx;
        final items = await _playAlbumUseCase.execute(
          songs,
          playIndex: idx,
          onResolvedLeadIndex: (i) => leadIndex = i,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(
          items,
          initialIndex: leadIndex.clamp(0, items.length - 1),
          shouldAbort: aborted,
        );

      case AaMediaId.ctxPlaylist:
        final rawVideos = await _musicRepo.getPlaylistVideos(target.contextId);
        if (aborted()) return;
        final videos = playableVideos(rawVideos)
            .take(100)
            .toList(growable: false);
        if (videos.isEmpty) return;
        final idx = _resolveIndex(videos, (e) => e.videoId, target);
        var leadIndex = idx;
        final items = await _playPlaylistUseCase.execute(
          videos,
          playIndex: idx,
          onResolvedLeadIndex: (i) => leadIndex = i,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(
          items,
          initialIndex: leadIndex.clamp(0, items.length - 1),
          shouldAbort: aborted,
        );

      case AaMediaId.ctxLocalPlaylist:
        final pid = int.tryParse(target.contextId);
        if (pid == null) return;
        final entries = await _libraryRepo.getPlaylistEntries(pid);
        if (aborted() || entries.isEmpty) return;
        final idx = _resolveIndex(entries, (e) => e.videoId, target);
        final items = await _playLocalPlaylistUseCase.execute(
          entries,
          playIndex: idx,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxFavorites:
        final songs = await _libraryBuilder.getSortedFavorites();
        if (aborted() || songs.isEmpty) return;
        final idx = _resolveIndex(songs, (s) => s.videoId, target);
        final items = await _playSmartMixUseCase.execute(
          songs: songs,
          playIndex: idx,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxHistory:
        final history = await _libraryRepo.getRecentHistory(limit: 50);
        if (aborted() || history.isEmpty) return;
        final idx = _resolveIndex(history, (h) => h.videoId, target);
        final items = await _resolveLeadAndMap(
          history,
          playIndex: idx,
          videoIdOf: (h) => h.videoId,
          toTrack: (h, url) => AaContentMapper.historyToQueueTrack(h, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxMix:
        final songs = await _libraryBuilder.fetchMixSongs(target.contextId);
        if (aborted() || songs.isEmpty) return;
        final idx = _resolveIndex(
          songs,
          (s) => (s as dynamic).videoId as String,
          target,
        );
        final items = await _playSmartMixUseCase.execute(
          songs: songs,
          playIndex: idx,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxArtist:
        final artist = await _musicRepo.getArtist(target.contextId);
        if (aborted()) return;
        var songs = playableSongs(artist.topSongs);
        if (songs.isEmpty) {
          songs = playableSongs(
            await _musicRepo.getArtistSongs(target.contextId),
          );
          if (aborted()) return;
        }
        if (songs.isEmpty) return;
        final idx = _resolveIndex(songs, (s) => s.videoId, target);
        var leadIndex = idx;
        final items = await _playAlbumUseCase.execute(
          songs,
          playIndex: idx,
          onResolvedLeadIndex: (i) => leadIndex = i,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(
          items,
          initialIndex: leadIndex.clamp(0, items.length - 1),
          shouldAbort: aborted,
        );

      case AaMediaId.ctxPodcast:
        final podcast = await _musicRepo.getPodcast(
          target.contextId,
          limit: 100,
        );
        if (aborted()) return;
        final playable = podcast.episodes
            .where((e) => e.videoId.isNotEmpty)
            .take(100)
            .toList(growable: false);
        if (playable.isEmpty) return;
        final idx = _resolveIndex(playable, (e) => e.videoId, target);
        final items = await _playPodcastUseCase.execute(
          playable,
          podcastBrowseId: target.contextId,
          podcastName: podcast.name,
          authorName: podcast.author?.name,
          authorId: podcast.author?.artistId,
          playIndex: idx,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxSavedEpisodes:
        final saved = await _libraryBuilder.getSortedSavedEpisodes();
        if (aborted() || saved.isEmpty) return;
        final idx = _resolveIndex(saved, (e) => e.videoId, target);
        final items = await _resolveLeadAndMap(
          saved,
          playIndex: idx,
          videoIdOf: (e) => e.videoId,
          toTrack: (e, url) =>
              AaContentMapper.likedEpisodeToQueueTrack(e, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxDownloadGroup:
        final group = await _downloadsBuilder.findGroup(target.contextId);
        if (aborted() || group == null || group.tracks.isEmpty) return;
        final tracks = AaDownloadsBuilder.sortGroupTracks(group);
        final idx = _resolveIndex(tracks, (d) => d.videoId, target);
        final items = await _resolveLeadAndMap(
          tracks,
          playIndex: idx,
          videoIdOf: (d) => d.videoId,
          toTrack: (d, url) =>
              AaContentMapper.downloadToQueueTrack(d, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxAskMix:
        final askRef = AaMediaId.tryParseAskMix(target.contextId);
        if (askRef == null) return;
        final mix = await _homeBuilder.findAskMix(
          askRef.messageId,
          askRef.attachmentIndex,
        );
        if (aborted() || mix == null || mix.tracks.isEmpty) return;
        final idx = _resolveIndex(mix.tracks, (t) => t.videoId, target);
        final items = await _resolveLeadAndMap(
          mix.tracks,
          playIndex: idx,
          videoIdOf: (t) => t.videoId,
          toTrack: (t, url) =>
              AaContentMapper.askTrackToQueueTrack(t, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, initialIndex: idx, shouldAbort: aborted);

      case AaMediaId.ctxHomeSection:
        final sectionIdx = int.tryParse(target.contextId);
        if (sectionIdx != null) {
          final contents = await _homeBuilder.resolveHomeSectionSongs(
            sectionIdx,
          );
          if (aborted()) return;
          final idx = contents.indexWhere((c) {
            if (c is SongDetailed) return c.videoId == target.videoId;
            if (c is VideoDetailed) return c.videoId == target.videoId;
            if (c is EpisodeDetailed) return c.videoId == target.videoId;
            return false;
          });
          if (idx >= 0) {
            final item = await _playVideoIdUseCase.execute(target.videoId);
            if (aborted()) return;
            final items = <MediaItem>[];
            for (var i = 0; i < contents.length; i++) {
              if (i == idx) {
                items.add(item);
              } else {
                items.addAll(
                  AaContentMapper.homeContentToMediaItems(contents[i]),
                );
              }
            }
            if (items.isNotEmpty) {
              await _playNow(
                items,
                initialIndex: idx.clamp(0, items.length - 1),
                shouldAbort: aborted,
              );
              return;
            }
          }
        }
        final item = await _playVideoIdUseCase.execute(target.videoId);
        if (aborted()) return;
        await _playNow([item], shouldAbort: aborted);

      default:
        final item = await _playVideoIdUseCase.execute(target.videoId);
        if (aborted()) return;
        await _playNow([item], shouldAbort: aborted);
    }
  }

  Future<void> _handleAction(AaActionTarget action) async {
    if (action.action == AaMediaId.actAffinity) {
      await _handleAffinity(action.targetKind, action.targetId);
      return;
    }

    if (action.action == AaMediaId.actPulseDrop) {
      await _handlePulseDrop(action.targetId);
      return;
    }

    final shuffle = action.action == AaMediaId.actShuffle;
    final radio = action.action == AaMediaId.actRadio;
    final v = ++_operationVersion;
    bool aborted() => _operationVersion != v;

    switch (action.targetKind) {
      case AaMediaId.ctxAlbum:
        final albumId = await _musicRepo.resolveAlbumId(action.targetId);
        if (aborted()) return;
        final album = await _musicRepo.getAlbum(albumId);
        if (aborted()) return;
        final songs = shuffle
            ? (List<SongDetailed>.from(album.songs)..shuffle())
            : album.songs;
        final items = await _playAlbumUseCase.execute(songs);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxPlaylist:
        final videos = await _musicRepo.getPlaylistVideos(action.targetId);
        if (aborted()) return;
        final list = shuffle
            ? (List<VideoDetailed>.from(videos)..shuffle())
            : videos;
        final items = await _playPlaylistUseCase.execute(list);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxLocalPlaylist:
        final pid = int.tryParse(action.targetId);
        if (pid == null) return;
        var entries = await _libraryRepo.getPlaylistEntries(pid);
        if (aborted() || entries.isEmpty) return;
        if (shuffle) {
          entries = List<PlaylistEntryModel>.from(entries)..shuffle();
        }
        final items = await _playLocalPlaylistUseCase.execute(entries);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxArtist:
        final artist = await _musicRepo.getArtist(action.targetId);
        if (aborted()) return;
        if (radio && artist.radioId != null && artist.radioId!.isNotEmpty) {
          final seed = artist.topSongs.isNotEmpty
              ? artist.topSongs.first.videoId
              : '';
          final res = await _startRadioUseCase.execute(
            seed,
            playlistId: artist.radioId,
            radio: true,
          );
          if (aborted()) return;
          final remaining = _startRadioUseCase.toPendingItems(res.remaining);
          await _playNow([res.firstItem, ...remaining], shouldAbort: aborted);
          return;
        }
        if (shuffle &&
            artist.shuffleId != null &&
            artist.shuffleId!.isNotEmpty) {
          final seed = artist.topSongs.isNotEmpty
              ? artist.topSongs.first.videoId
              : '';
          final res = await _startRadioUseCase.execute(
            seed,
            playlistId: artist.shuffleId,
            radio: false,
            shuffle: true,
          );
          if (aborted()) return;
          final remaining = _startRadioUseCase.toPendingItems(res.remaining);
          await _playNow([res.firstItem, ...remaining], shouldAbort: aborted);
          return;
        }
        var songs = playableSongs(
          await _musicRepo.getArtistSongs(action.targetId),
        );
        if (aborted()) return;
        if (songs.isEmpty) songs = playableSongs(artist.topSongs);
        if (songs.isEmpty) return;
        if (radio) {
          final res = await _startRadioUseCase.execute(songs.first.videoId);
          if (aborted()) return;
          final remaining = _startRadioUseCase.toPendingItems(res.remaining);
          await _playNow([res.firstItem, ...remaining], shouldAbort: aborted);
          return;
        }
        if (shuffle) songs = List<SongDetailed>.from(songs)..shuffle();
        final items = await _playAlbumUseCase.execute(songs);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxPodcast:
        final podcast = await _musicRepo.getPodcast(
          action.targetId,
          limit: 100,
        );
        if (aborted()) return;
        var episodes = podcast.episodes
            .where((e) => e.videoId.isNotEmpty)
            .toList(growable: false);
        if (episodes.isEmpty) return;
        if (shuffle) {
          episodes = List<PodcastEpisode>.from(episodes)..shuffle();
        }
        final items = await _playPodcastUseCase.execute(
          episodes,
          podcastBrowseId: action.targetId,
          podcastName: podcast.name,
          authorName: podcast.author?.name,
          authorId: podcast.author?.artistId,
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxSavedEpisodes:
        var saved = await _libraryBuilder.getSortedSavedEpisodes();
        if (aborted() || saved.isEmpty) return;
        if (shuffle) saved = List<LikedEpisodeModel>.from(saved)..shuffle();
        final items = await _resolveLeadAndMap(
          saved,
          playIndex: 0,
          videoIdOf: (e) => e.videoId,
          toTrack: (e, url) =>
              AaContentMapper.likedEpisodeToQueueTrack(e, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxFavorites:
        var songs = await _libraryBuilder.getSortedFavorites();
        if (aborted() || songs.isEmpty) return;
        if (shuffle) songs = List<LikedSongModel>.from(songs)..shuffle();
        final items = await _playSmartMixUseCase.execute(songs: songs);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxHistory:
        var history = await _libraryRepo.getRecentHistory(limit: 50);
        if (aborted() || history.isEmpty) return;
        if (shuffle) history = List<HistoryModel>.from(history)..shuffle();
        final items = await _resolveLeadAndMap(
          history,
          playIndex: 0,
          videoIdOf: (h) => h.videoId,
          toTrack: (h, url) => AaContentMapper.historyToQueueTrack(h, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxMix:
        var songs = await _libraryBuilder.fetchMixSongs(action.targetId);
        if (aborted() || songs.isEmpty) return;
        if (shuffle) songs = List<dynamic>.from(songs)..shuffle();
        final items = await _playSmartMixUseCase.execute(songs: songs);
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxDownloads:
        var completed = await _downloadsBuilder.getCompletedDownloads();
        if (aborted() || completed.isEmpty) return;
        if (shuffle) completed = List<DownloadModel>.from(completed)..shuffle();
        final items = await _resolveLeadAndMap(
          completed,
          playIndex: 0,
          videoIdOf: (d) => d.videoId,
          toTrack: (d, url) =>
              AaContentMapper.downloadToQueueTrack(d, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxDownloadGroup:
        final group = await _downloadsBuilder.findGroup(action.targetId);
        if (aborted() || group == null || group.tracks.isEmpty) return;
        var tracks = AaDownloadsBuilder.sortGroupTracks(group);
        if (shuffle) tracks = List<DownloadModel>.from(tracks)..shuffle();
        final items = await _resolveLeadAndMap(
          tracks,
          playIndex: 0,
          videoIdOf: (d) => d.videoId,
          toTrack: (d, url) =>
              AaContentMapper.downloadToQueueTrack(d, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);

      case AaMediaId.ctxAskMix:
        final askRef = AaMediaId.tryParseAskMix(action.targetId);
        if (askRef == null) return;
        final mix = await _homeBuilder.findAskMix(
          askRef.messageId,
          askRef.attachmentIndex,
        );
        if (aborted() || mix == null || mix.tracks.isEmpty) return;
        final tracks = shuffle ? (List.of(mix.tracks)..shuffle()) : mix.tracks;
        final items = await _resolveLeadAndMap(
          tracks,
          playIndex: 0,
          videoIdOf: (t) => t.videoId,
          toTrack: (t, url) =>
              AaContentMapper.askTrackToQueueTrack(t, url: url),
        );
        if (aborted() || items.isEmpty) return;
        await _playNow(items, shouldAbort: aborted);
    }
  }

  Future<void> _handleAffinity(String targetKind, String targetId) async {
    switch (targetKind) {
      case AaMediaId.ctxAlbum:
        final albumId = await _musicRepo.resolveAlbumId(targetId);
        final existing = await _libraryRepo.getLikedAlbum(albumId);
        if (existing != null) {
          await _libraryRepo.deleteLikedAlbum(albumId);
        } else {
          final album = await _musicRepo.getAlbum(albumId);
          await _libraryRepo.toggleLikedAlbum(
            LikedAlbumModel(
              albumId: albumId,
              name: album.name,
              artistName: displayArtists(album.artists),
              artistId: primaryArtistId(album.artists),
              thumbnailUrl: album.thumbnails.isNotEmpty
                  ? album.thumbnails.last.url
                  : null,
              year: album.year,
              addedAt: DateTime.now(),
            ),
          );
        }
        _notifyChanged(AaMediaId.album(albumId));
        _notifyChanged(AaMediaId.albums);

      case AaMediaId.ctxArtist:
        final existing = await _libraryRepo.getFollowedArtist(targetId);
        if (existing != null) {
          await _libraryRepo.deleteFollowedArtist(targetId);
        } else {
          final artist = await _musicRepo.getArtist(targetId);
          await _libraryRepo.toggleFollowedArtist(
            FollowedArtistModel(
              artistId: targetId,
              name: artist.name,
              thumbnailUrl: artist.thumbnails.isNotEmpty
                  ? artist.thumbnails.last.url
                  : null,
              addedAt: DateTime.now(),
            ),
          );
        }
        _notifyChanged(AaMediaId.artist(targetId));
        _notifyChanged(AaMediaId.artists);

      case AaMediaId.ctxPodcast:
        final existing = await _libraryRepo.getLikedPodcast(targetId);
        if (existing != null) {
          await _libraryRepo.deleteLikedPodcast(targetId);
        } else {
          final podcast = await _musicRepo.getPodcast(targetId, limit: 1);
          await _libraryRepo.toggleLikedPodcast(
            LikedPodcastModel(
              browseId: targetId,
              name: podcast.name,
              authorName: podcast.author?.name,
              authorId: podcast.author?.artistId,
              thumbnailUrl: podcast.thumbnails.isNotEmpty
                  ? podcast.thumbnails.last.url
                  : null,
              episodeCount: podcast.episodes.length,
              addedAt: DateTime.now(),
            ),
          );
        }
        _notifyChanged(AaMediaId.podcast(targetId));
        _notifyChanged(AaMediaId.podcasts);

      case AaMediaId.ctxPlaylist:
        final existing = await _libraryRepo.getLikedPlaylist(targetId);
        if (existing != null) {
          await _libraryRepo.deleteLikedPlaylist(targetId);
        } else {
          final playlist = await _musicRepo.getPlaylist(targetId);
          await _libraryRepo.toggleLikedPlaylist(
            LikedPlaylistModel(
              playlistId: targetId,
              name: playlist.name,
              thumbnailUrl: playlist.thumbnails.isNotEmpty
                  ? playlist.thumbnails.last.url
                  : null,
              videoCount: playlist.videoCount,
              addedAt: DateTime.now(),
            ),
          );
        }
        _notifyChanged(AaMediaId.remotePlaylist(targetId));
        _notifyChanged(AaMediaId.playlists);
    }
  }

  Future<void> _handlePulseDrop(String dropId) async {
    if (_askStorageRepo == null) return;
    final drops = await _askStorageRepo.getActiveDrops();
    final drop = drops.where((d) => d.id == dropId).firstOrNull;
    if (drop == null) return;
    await _askStorageRepo.markDropRead(dropId);
    _notifyChanged(AaMediaId.home);

    final seed = drop.seedId ?? '';
    if (drop.kind == 'new_release' && seed.startsWith('release:')) {
      final albumId = seed.substring('release:'.length);
      await _handleAction(
        AaActionTarget(
          action: AaMediaId.actPlay,
          targetKind: AaMediaId.ctxAlbum,
          targetId: albumId,
        ),
      );
      return;
    }
    if (drop.kind == 'new_podcast_episode') {
      final podcasts = await _libraryRepo.getAllLikedPodcasts();
      for (final p in podcasts) {
        if (seed.toLowerCase().contains(p.browseId.toLowerCase()) ||
            drop.body.toLowerCase().contains(p.name.toLowerCase())) {
          await _handleAction(
            AaActionTarget(
              action: AaMediaId.actPlay,
              targetKind: AaMediaId.ctxPodcast,
              targetId: p.browseId,
            ),
          );
          return;
        }
      }
    }
    if (drop.kind == 'forgotten_favorites') {
      await _handleAction(
        const AaActionTarget(
          action: AaMediaId.actPlay,
          targetKind: AaMediaId.ctxMix,
          targetId: 'forgotten_favorites',
        ),
      );
      return;
    }
    if (drop.kind == 'heavy_rotation' ||
        drop.kind == 'comeback_mix' ||
        drop.kind == 'weekly_recap') {
      await _handleAction(
        const AaActionTarget(
          action: AaMediaId.actPlay,
          targetKind: AaMediaId.ctxMix,
          targetId: 'most_played',
        ),
      );
      return;
    }

    await _playFromSearch(drop.starterPrompt, null);
  }

  Future<List<MediaItem>> _resolveLeadAndMap<T>(
    List<T> items, {
    required int playIndex,
    required String Function(T item) videoIdOf,
    required QueueTrack Function(T item, String? url) toTrack,
  }) async {
    final firstUrl = await _playVideoIdUseCase.resolveUrl(
      videoIdOf(items[playIndex]),
    );
    return [
      for (var i = 0; i < items.length; i++)
        toTrack(items[i], i == playIndex ? firstUrl : null).toFreshMediaItem(),
    ];
  }

  void _notifyChanged(String parentMediaId) {
    try {
      AudioServicePlatform.instance.notifyChildrenChanged(
        NotifyChildrenChangedRequest(parentMediaId: parentMediaId),
      );
    } catch (_) {}
  }
}
