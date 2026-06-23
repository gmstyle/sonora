import 'package:audio_service/audio_service.dart';
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
  }) async {
    await _repo.updateLikedSongMetadata(
      videoId,
      artistId: artistId,
      albumId: albumId,
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

  Future<void> deletePlaylist(int id) async {
    await _repo.deletePlaylist(id);
  }

  Future<void> updatePlaylist(int id, {String? name}) async {
    await _repo.updatePlaylist(id, name: name);
  }

  // ── Playlist entries ─────────────────────────────────────────────────────────

  /// Adds [videoId] to playlist, automatically computing the next position.
  Future<void> addEntryToPlaylist(
    int playlistId,
    String videoId, {
    String? title,
    String? artist,
    String? thumbnailUrl,
    bool isVideo = false,
  }) async {
    final entries = await _repo.getPlaylistEntries(playlistId);
    await _repo.addEntry(
      playlistId,
      videoId,
      entries.length,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      isVideo: isVideo,
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
    bool isVideo = false,
  }) async {
    await _repo.recordPlay(
      videoId,
      title,
      artist,
      thumbnailUrl: thumbnailUrl,
      isVideo: isVideo,
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

  // ── Local playlist play helpers ──────────────────────────────────────────────

  /// Resolves metadata for each entry from liked_songs (best-effort) and
  /// returns a list of [MediaItem]s ready for [PlayerNotifier.playNow].
  /// Falls back to stored entry metadata when unavailable in liked_songs.
  Future<List<MediaItem>> buildLocalPlaylistItems(
    List<PlaylistEntryModel> entries,
  ) async {
    final items = <MediaItem>[];
    for (final entry in entries) {
      final liked = await _repo.getLikedSong(entry.videoId);
      final title = liked?.title ?? entry.title ?? entry.videoId;
      final artist = liked?.artist ?? entry.artist ?? '';
      final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      items.add(
        MediaItem(
          id: entry.videoId,
          title: title,
          artist: artist,
          artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl) : null,
          extras: {
            'videoId': entry.videoId,
            'isVideo': liked?.isVideo ?? entry.isVideo,
          },
        ),
      );
    }
    return items;
  }
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
