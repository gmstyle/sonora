import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library_models.dart';
import '../../domain/repositories/library_repository.dart';
import '../features/library/providers/library_provider.dart';
import 'library_repository_provider.dart';

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

  // ── Followed artists ─────────────────────────────────────────────────────────

  Future<void> toggleFollowedArtist(FollowedArtistModel artist) async {
    await _repo.toggleFollowedArtist(artist);
    ref.invalidate(followedArtistProvider(artist.artistId));
    ref.invalidate(followedArtistsProvider);
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
  Future<void> addEntryToPlaylist(int playlistId, String videoId) async {
    final entries = await _repo.getPlaylistEntries(playlistId);
    await _repo.addEntry(playlistId, videoId, entries.length);
  }

  Future<void> removeEntry(int playlistId, String videoId) async {
    await _repo.removeEntry(playlistId, videoId);
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
