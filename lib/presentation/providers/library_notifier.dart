import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library_models.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/music_repository.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';

// ── Single-item query providers ───────────────────────────────────────────────

/// Watches whether a specific song is liked. Invalided by [LibraryNotifier].
final likedSongProvider = StreamProvider.family<LikedSongModel?, String>((
  ref,
  videoId,
) {
  return ref.watch(libraryRepositoryProvider).watchLikedSong(videoId);
});

/// Watches whether a specific artist is followed. Reacts to database streams.
final followedArtistProvider =
    StreamProvider.family<FollowedArtistModel?, String>((ref, artistId) {
      return ref.watch(libraryRepositoryProvider).watchFollowedArtist(artistId);
    });

/// Watches whether a specific album is liked. Reacts to database streams.
final likedAlbumProvider = StreamProvider.family<LikedAlbumModel?, String>((
  ref,
  albumId,
) {
  return ref.watch(libraryRepositoryProvider).watchLikedAlbum(albumId);
});

/// Watches whether a specific playlist is liked. Reacts to database streams.
final likedPlaylistProvider =
    StreamProvider.family<LikedPlaylistModel?, String>((ref, playlistId) {
      return ref
          .watch(libraryRepositoryProvider)
          .watchLikedPlaylist(playlistId);
    });

/// Watches whether a specific podcast is subscribed.
final likedPodcastProvider = StreamProvider.family<LikedPodcastModel?, String>((
  ref,
  browseId,
) {
  return ref.watch(libraryRepositoryProvider).watchLikedPodcast(browseId);
});

/// Watches whether a specific episode is saved.
final likedEpisodeProvider = StreamProvider.family<LikedEpisodeModel?, String>((
  ref,
  videoId,
) {
  return ref.watch(libraryRepositoryProvider).watchLikedEpisode(videoId);
});

// ── LibraryNotifier ───────────────────────────────────────────────────────────

final libraryNotifierProvider = NotifierProvider<LibraryNotifier, void>(
  LibraryNotifier.new,
);

/// Notifier that centralises all library mutations (liked songs, followed artists,
/// playlists, history, playlist entries). Widgets must never call
/// [libraryRepositoryProvider] directly for mutations — use this notifier instead.
class LibraryNotifier extends Notifier<void> {
  @override
  void build() {}

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);
  MusicRepository get _musicRepo => ref.read(musicRepositoryProvider);

  // ── Liked songs ─────────────────────────────────────────────────────────────

  Future<void> toggleLikedSong(LikedSongModel song) async {
    await _repo.toggleLikedSong(song);
  }

  Future<void> deleteLikedSong(String videoId) async {
    await _repo.deleteLikedSong(videoId);
  }

  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
    String? artistsJson,
  }) async {
    await _repo.updateLikedSongMetadata(
      videoId,
      artistId: artistId,
      albumId: albumId,
      artistsJson: artistsJson,
    );
  }

  // ── Followed artists ─────────────────────────────────────────────────────────

  Future<void> toggleFollowedArtist(FollowedArtistModel artist) async {
    await _repo.toggleFollowedArtist(artist);
  }

  // ── Liked Albums ─────────────────────────────────────────────────────────────

  Future<void> toggleLikedAlbum(LikedAlbumModel album) async {
    await _repo.toggleLikedAlbum(album);
  }

  Future<void> deleteLikedAlbum(String albumId) async {
    await _repo.deleteLikedAlbum(albumId);
  }

  // ── Liked Playlists ──────────────────────────────────────────────────────────

  Future<void> toggleLikedPlaylist(LikedPlaylistModel playlist) async {
    await _repo.toggleLikedPlaylist(playlist);
  }

  // ── Liked Podcasts ───────────────────────────────────────────────────────────

  Future<void> toggleLikedPodcast(LikedPodcastModel podcast) async {
    await _repo.toggleLikedPodcast(podcast);
  }

  Future<void> deleteLikedPodcast(String browseId) async {
    await _repo.deleteLikedPodcast(browseId);
  }

  // ── Liked Episodes ───────────────────────────────────────────────────────────

  Future<void> toggleLikedEpisode(LikedEpisodeModel episode) async {
    await _repo.toggleLikedEpisode(episode);
  }

  Future<void> deleteLikedEpisode(String videoId) async {
    await _repo.deleteLikedEpisode(videoId);
  }

  bool _thumbnailRefreshRunning = false;
  final Set<String> _recentlyRefreshedPlaylists = {};

  /// Refreshes expired YouTube playlist thumbnail URLs by re-fetching
  /// playlist metadata from the API and persisting fresh URLs to the DB.
  Future<void> refreshPlaylistThumbnailsIfNeeded() async {
    if (_thumbnailRefreshRunning) return;
    _thumbnailRefreshRunning = true;
    try {
      final playlists = await _repo.getAllLikedPlaylists();
      final stale =
          playlists
              .where(
                (p) =>
                    p.thumbnailUrl != null &&
                    _isThumbnailStale(p.thumbnailUrl!) &&
                    !_recentlyRefreshedPlaylists.contains(p.playlistId),
              )
              .toList();
      if (stale.isEmpty) return;
      for (final playlist in stale) {
        try {
          final fresh = await _musicRepo.getPlaylist(playlist.playlistId);
          final freshUrl =
              fresh.thumbnails.isNotEmpty ? fresh.thumbnails.last.url : null;
          if (freshUrl != null && freshUrl != playlist.thumbnailUrl) {
            await _repo.updateLikedPlaylistThumbnail(
              playlist.playlistId,
              freshUrl,
            );
          }
          _recentlyRefreshedPlaylists.add(playlist.playlistId);
          if (_recentlyRefreshedPlaylists.length > 100) {
            _recentlyRefreshedPlaylists.clear();
          }
        } catch (_) {}
      }
    } finally {
      _thumbnailRefreshRunning = false;
    }
  }

  // ── Playlists ────────────────────────────────────────────────────────────────

  Future<void> createPlaylist(String name) async {
    await _repo.createPlaylist(name);
  }

  /// Creates a local playlist and fills it with [tracks] (history / liked rows).
  Future<LocalPlaylistModel> createPlaylistWithTracks(
    String name,
    List<dynamic> tracks,
  ) async {
    final id = await _repo.createPlaylist(name);
    final seen = <String>{};
    final entries = <PlaylistEntryModel>[];
    for (final track in tracks) {
      final videoId = _trackVideoId(track);
      if (videoId == null || videoId.isEmpty || seen.contains(videoId)) {
        continue;
      }
      seen.add(videoId);
      entries.add(
        PlaylistEntryModel(
          playlistId: id,
          videoId: videoId,
          position: entries.length,
          title: _trackTitle(track),
          artist: _trackArtist(track),
          artistsJson: track is LikedSongModel ? track.artistsJson : null,
          thumbnailUrl: _trackThumbnail(track),
          duration: _trackDuration(track),
          isVideo: _trackIsVideo(track),
          isExplicit: _trackIsExplicit(track),
        ),
      );
    }
    if (entries.isNotEmpty) {
      await _repo.replacePlaylistEntries(id, entries);
    }
    final playlist = await _repo.getPlaylist(id);
    if (playlist == null) {
      return LocalPlaylistModel(id: id, name: name, createdAt: DateTime.now());
    }
    return playlist;
  }

  String? _trackVideoId(dynamic track) {
    if (track is HistoryModel) return track.videoId;
    if (track is LikedSongModel) return track.videoId;
    try {
      return track.videoId as String?;
    } catch (_) {
      return null;
    }
  }

  String? _trackTitle(dynamic track) {
    if (track is HistoryModel) return track.title;
    if (track is LikedSongModel) return track.title;
    try {
      return track.title as String?;
    } catch (_) {
      return null;
    }
  }

  String? _trackArtist(dynamic track) {
    if (track is HistoryModel) return track.artist;
    if (track is LikedSongModel) return track.artist;
    try {
      return track.artist as String?;
    } catch (_) {
      return null;
    }
  }

  String? _trackThumbnail(dynamic track) {
    if (track is HistoryModel) return track.thumbnailUrl;
    if (track is LikedSongModel) return track.thumbnailUrl;
    try {
      return track.thumbnailUrl as String?;
    } catch (_) {
      return null;
    }
  }

  int? _trackDuration(dynamic track) {
    if (track is HistoryModel) return track.duration;
    if (track is LikedSongModel) return track.duration;
    try {
      return track.duration as int?;
    } catch (_) {
      return null;
    }
  }

  bool _trackIsVideo(dynamic track) {
    if (track is HistoryModel) return track.isVideo;
    if (track is LikedSongModel) return track.isVideo;
    try {
      return track.isVideo as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  bool _trackIsExplicit(dynamic track) {
    if (track is HistoryModel) return track.isExplicit;
    if (track is LikedSongModel) return track.isExplicit;
    try {
      return track.isExplicit as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> deletePlaylist(int id) async {
    await _repo.deletePlaylist(id);
  }

  Future<void> updatePlaylist(int id, {String? name}) async {
    await _repo.updatePlaylist(id, name: name);
  }

  Future<void> unlinkPlaylist(int id) async {
    await _repo.unlinkPlaylist(id);
  }

  // ── Playlist entries ─────────────────────────────────────────────────────────

  /// Adds [videoId] to playlist, automatically computing the next position.
  Future<void> addEntryToPlaylist(
    int playlistId,
    String videoId, {
    String? title,
    String? artist,
    String? artistsJson,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) async {
    final entries = await _repo.getPlaylistEntries(playlistId);
    await _repo.addEntry(
      playlistId,
      videoId,
      entries.length,
      title: title,
      artist: artist,
      artistsJson: artistsJson,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      isVideo: isVideo,
      isExplicit: isExplicit,
    );
  }

  Future<void> removeEntry(int playlistId, String videoId) async {
    await _repo.removeEntry(playlistId, videoId);
  }

  /// Persists a new position order for all entries in [playlistId].
  Future<void> reorderPlaylistEntries(
    int playlistId,
    List<PlaylistEntryModel> reordered,
  ) async {
    final videoIds = reordered.map((e) => e.videoId).toList();
    await _repo.reorderEntries(playlistId, videoIds);
  }

  // ── History ──────────────────────────────────────────────────────────────────

  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
    String contentType = 'song',
    String? podcastBrowseId,
  }) async {
    await _repo.recordPlay(
      videoId,
      title,
      artist,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      isVideo: isVideo,
      isExplicit: isExplicit,
      contentType: contentType,
      podcastBrowseId: podcastBrowseId,
    );
  }

  Future<void> clearHistory() async {
    await _repo.clearHistory();
  }

  // ── Search history ────────────────────────────────────────────────────────────

  Future<void> insertSearchEntry(String query) async {
    await _repo.insertSearchEntry(query);
  }

  Future<void> clearSearchHistory() async {
    await _repo.clearSearchHistory();
  }

  Future<void> deleteSearchEntry(String query) async {
    await _repo.deleteSearchEntry(query);
  }

  // ── Read-only helpers exposed to shared widgets ───────────────────────────────

  /// Returns all local playlists. Used by shared widgets that cannot import
  /// feature-level providers directly (e.g. ContextMenuSheet).
  Future<List<LocalPlaylistModel>> getAllPlaylists() => _repo.getAllPlaylists();
}

/// Returns true when [url] looks like a signed YouTube CDN thumbnail that
/// can expire (e.g. `generated_thumbnail.jpg` with `sqp` parameter).
bool _isThumbnailStale(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.queryParameters.containsKey('sqp')) return true;
  if (url.contains('generated_thumbnail')) return true;
  if (uri.host == 'i.ytimg.com' && uri.path.contains('/pl_c/')) return true;
  return false;
}
