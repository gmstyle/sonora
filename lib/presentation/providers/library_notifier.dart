import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library_models.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/music_repository.dart';
import '../features/library/providers/library_provider.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';

// ── Single-item query providers ───────────────────────────────────────────────

/// Watches whether a specific song is liked. Invalided by [LibraryNotifier].
final likedSongProvider = FutureProvider.family<LikedSongModel?, String>((
  ref,
  videoId,
) {
  return ref.watch(libraryRepositoryProvider).getLikedSong(videoId);
});

/// Watches whether a specific artist is followed. Invalided by [LibraryNotifier].
final followedArtistProvider =
    FutureProvider.family<FollowedArtistModel?, String>((ref, artistId) {
      return ref.watch(libraryRepositoryProvider).getFollowedArtist(artistId);
    });

/// Watches whether a specific album is liked. Invalidated by [LibraryNotifier].
final likedAlbumProvider = FutureProvider.family<LikedAlbumModel?, String>((
  ref,
  albumId,
) {
  return ref.watch(libraryRepositoryProvider).getLikedAlbum(albumId);
});

/// Watches whether a specific playlist is liked. Invalidated by [LibraryNotifier].
final likedPlaylistProvider =
    FutureProvider.family<LikedPlaylistModel?, String>((ref, playlistId) {
      return ref.watch(libraryRepositoryProvider).getLikedPlaylist(playlistId);
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
    ref.invalidate(likedSongProvider(song.videoId));
    ref.invalidate(likedSongsProvider);
  }

  Future<void> deleteLikedSong(String videoId) async {
    await _repo.deleteLikedSong(videoId);
    ref.invalidate(likedSongProvider(videoId));
    ref.invalidate(likedSongsProvider);
  }

  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
  }) async {
    await _repo.updateLikedSongMetadata(videoId, artistId: artistId, albumId: albumId);
    ref.invalidate(likedSongProvider(videoId));
    ref.invalidate(likedSongsProvider);
  }

  // ── Followed artists ─────────────────────────────────────────────────────────

  Future<void> toggleFollowedArtist(FollowedArtistModel artist) async {
    await _repo.toggleFollowedArtist(artist);
    ref.invalidate(followedArtistProvider(artist.artistId));
    ref.invalidate(followedArtistsProvider);
  }

  // ── Liked Albums ─────────────────────────────────────────────────────────────

  Future<void> toggleLikedAlbum(LikedAlbumModel album) async {
    await _repo.toggleLikedAlbum(album);
    ref.invalidate(likedAlbumProvider(album.albumId));
    ref.invalidate(likedAlbumsProvider);
  }

  Future<void> deleteLikedAlbum(String albumId) async {
    await _repo.deleteLikedAlbum(albumId);
    ref.invalidate(likedAlbumProvider(albumId));
    ref.invalidate(likedAlbumsProvider);
  }

  // ── Liked Playlists ──────────────────────────────────────────────────────────

  Future<void> toggleLikedPlaylist(LikedPlaylistModel playlist) async {
    await _repo.toggleLikedPlaylist(playlist);
    ref.invalidate(likedPlaylistProvider(playlist.playlistId));
    ref.invalidate(likedPlaylistsProvider);
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
      var changed = false;
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
            changed = true;
          }
          _recentlyRefreshedPlaylists.add(playlist.playlistId);
          if (_recentlyRefreshedPlaylists.length > 100) {
            _recentlyRefreshedPlaylists.clear();
          }
        } catch (_) {}
      }
      if (changed) ref.invalidate(likedPlaylistsProvider);
    } finally {
      _thumbnailRefreshRunning = false;
    }
  }

  // ── Playlists ────────────────────────────────────────────────────────────────

  Future<void> createPlaylist(String name) async {
    await _repo.createPlaylist(name);
    ref.invalidate(playlistsProvider);
  }

  Future<void> deletePlaylist(int id) async {
    await _repo.deletePlaylist(id);
    ref.invalidate(playlistsProvider);
  }

  Future<void> updatePlaylist(int id, {String? name}) async {
    await _repo.updatePlaylist(id, name: name);
    ref.invalidate(playlistsProvider);
  }

  // ── Playlist entries ─────────────────────────────────────────────────────────

  /// Adds [videoId] to playlist, automatically computing the next position.
  Future<void> addEntryToPlaylist(int playlistId, String videoId) async {
    final entries = await _repo.getPlaylistEntries(playlistId);
    await _repo.addEntry(playlistId, videoId, entries.length);
    ref.invalidate(playlistEntriesProvider(playlistId));
  }

  Future<void> removeEntry(int playlistId, String videoId) async {
    await _repo.removeEntry(playlistId, videoId);
    ref.invalidate(playlistEntriesProvider(playlistId));
  }

  /// Persists a new position order for all entries in [playlistId].
  Future<void> reorderPlaylistEntries(
    int playlistId,
    List<PlaylistEntryModel> reordered,
  ) async {
    for (var i = 0; i < reordered.length; i++) {
      await _repo.addEntry(playlistId, reordered[i].videoId, i);
    }
  }

  // ── History ──────────────────────────────────────────────────────────────────

  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
  }) async {
    await _repo.recordPlay(videoId, title, artist, thumbnailUrl: thumbnailUrl);
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

  // ── Read-only helpers exposed to shared widgets ───────────────────────────────

  /// Returns all local playlists. Used by shared widgets that cannot import
  /// feature-level providers directly (e.g. ContextMenuSheet).
  Future<List<LocalPlaylistModel>> getAllPlaylists() => _repo.getAllPlaylists();

  // ── Local playlist play helpers ──────────────────────────────────────────────

  /// Resolves metadata for each entry from liked_songs (best-effort) and
  /// returns a list of [MediaItem]s ready for [PlayerNotifier.playNow].
  /// Items without a match in liked_songs use a minimal placeholder.
  Future<List<MediaItem>> buildLocalPlaylistItems(
    List<PlaylistEntryModel> entries,
  ) async {
    final items = <MediaItem>[];
    for (final entry in entries) {
      final liked = await _repo.getLikedSong(entry.videoId);
      if (liked != null) {
        items.add(
          MediaItem(
            id: entry.videoId,
            title: liked.title,
            artist: liked.artist,
            artUri:
                liked.thumbnailUrl != null
                    ? Uri.parse(liked.thumbnailUrl!)
                    : null,
            extras: {'videoId': entry.videoId, 'isVideo': false},
          ),
        );
      } else {
        items.add(
          MediaItem(
            id: entry.videoId,
            title: 'Loading...',
            artist: '',
            extras: {'videoId': entry.videoId, 'isVideo': false},
          ),
        );
      }
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
