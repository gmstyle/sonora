import '../../models/library_models.dart';
import '../../repositories/library_repository.dart';

enum PlaylistConflictStrategy { merge, keepBoth, overwrite }

class MergeLibraryUseCase {
  final LibraryRepository libraryRepository;

  MergeLibraryUseCase(this.libraryRepository);

  Future<Map<String, int>> execute(
    Map<String, dynamic> data, {
    PlaylistConflictStrategy conflictStrategy = PlaylistConflictStrategy.merge,
  }) async {
    int likedSongsCount = 0;
    int followedArtistsCount = 0;
    int likedAlbumsCount = 0;
    int likedPlaylistsCount = 0;
    int playlistsCount = 0;
    int playlistEntriesCount = 0;
    int historyCount = 0;
    int searchHistoryCount = 0;

    // 1. Synchronize Liked Songs (Native Upsert)
    final likedSongs =
        (data['likedSongs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    if (likedSongs.isNotEmpty) {
      final localSongs = await libraryRepository.getAllLikedSongs();
      final localSongIds = localSongs.map((s) => s.videoId).toSet();

      for (final s in likedSongs) {
        final videoId = s['videoId'] as String;
        if (!localSongIds.contains(videoId)) {
          await libraryRepository.ensureLikedSong(
            LikedSongModel(
              videoId: videoId,
              title: s['title'] as String,
              artist: s['artist'] as String,
              thumbnailUrl: s['thumbnailUrl'] as String?,
              artistId: s['artistId'] as String?,
              albumId: s['albumId'] as String?,
              addedAt: DateTime.parse(s['addedAt'] as String),
              duration: s['duration'] as int?,
              isVideo: s['isVideo'] as bool? ?? false,
              isExplicit: s['isExplicit'] as bool? ?? false,
            ),
          );
          likedSongsCount++;
        }
      }
    }

    // 2. Synchronize Followed Artists (Native Upsert)
    final followedArtists =
        (data['followedArtists'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (followedArtists.isNotEmpty) {
      final localArtists = await libraryRepository.getAllFollowedArtists();
      final localArtistIds = localArtists.map((a) => a.artistId).toSet();

      for (final a in followedArtists) {
        final artistId = a['artistId'] as String;
        if (!localArtistIds.contains(artistId)) {
          await libraryRepository.ensureFollowedArtist(
            FollowedArtistModel(
              artistId: artistId,
              name: a['name'] as String,
              thumbnailUrl: a['thumbnailUrl'] as String?,
              addedAt:
                  a['addedAt'] != null
                      ? DateTime.parse(a['addedAt'] as String)
                      : DateTime.now(),
            ),
          );
          followedArtistsCount++;
        }
      }
    }

    // 3. Synchronize Liked Albums (Native Upsert)
    final likedAlbums =
        (data['likedAlbums'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    if (likedAlbums.isNotEmpty) {
      final localAlbums = await libraryRepository.getAllLikedAlbums();
      final localAlbumIds = localAlbums.map((a) => a.albumId).toSet();

      for (final a in likedAlbums) {
        final albumId = a['albumId'] as String;
        if (!localAlbumIds.contains(albumId)) {
          await libraryRepository.ensureLikedAlbum(
            LikedAlbumModel(
              albumId: albumId,
              name: a['name'] as String,
              artistName: a['artistName'] as String,
              artistId: a['artistId'] as String?,
              thumbnailUrl: a['thumbnailUrl'] as String?,
              year: a['year'] as int?,
              addedAt: DateTime.parse(a['addedAt'] as String),
            ),
          );
          likedAlbumsCount++;
        }
      }
    }

    // 4. Synchronize Liked Playlists (Native Upsert)
    final likedPlaylists =
        (data['likedPlaylists'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (likedPlaylists.isNotEmpty) {
      final localLikedPlaylists =
          await libraryRepository.getAllLikedPlaylists();
      final localLikedPlaylistIds =
          localLikedPlaylists.map((p) => p.playlistId).toSet();

      for (final p in likedPlaylists) {
        final playlistId = p['playlistId'] as String;
        if (!localLikedPlaylistIds.contains(playlistId)) {
          await libraryRepository.ensureLikedPlaylist(
            LikedPlaylistModel(
              playlistId: playlistId,
              name: p['name'] as String,
              thumbnailUrl: p['thumbnailUrl'] as String?,
              videoCount: p['videoCount'] as int?,
              addedAt: DateTime.parse(p['addedAt'] as String),
            ),
          );
          likedPlaylistsCount++;
        }
      }
    }

    // 5. Synchronize Local Playlists and Entries
    final playlistsRaw =
        (data['playlists'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    final playlistEntriesRaw =
        data['playlistEntries'] as Map<String, dynamic>? ?? {};

    // Retrieve current local playlists to avoid duplicates by name
    final localPlaylists = await libraryRepository.getAllPlaylists();
    final nameToIdMap = {
      for (final p in localPlaylists) p.name.toLowerCase(): p.id,
    };

    for (final p in playlistsRaw) {
      final playlistName = p['name'] as String;
      final oldId = p['id'] as int;
      final createdAt =
          p['createdAt'] != null
              ? DateTime.tryParse(p['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();

      int targetPlaylistId;
      final existingPlaylistId = nameToIdMap[playlistName.toLowerCase()];
      final Set<String> existingVideoIds;
      int nextPosition;

      if (existingPlaylistId != null) {
        if (conflictStrategy == PlaylistConflictStrategy.overwrite) {
          targetPlaylistId = existingPlaylistId;
          final localEntries = await libraryRepository.getPlaylistEntries(
            targetPlaylistId,
          );
          for (final entry in localEntries) {
            await libraryRepository.removeEntry(
              targetPlaylistId,
              entry.videoId,
            );
          }
          existingVideoIds = const <String>{};
          nextPosition = 1;
        } else if (conflictStrategy == PlaylistConflictStrategy.keepBoth) {
          final renamedName = '$playlistName (Sync)';
          targetPlaylistId = await libraryRepository.createPlaylistWithDate(
            renamedName,
            description: p['description'] as String?,
            createdAt: createdAt,
          );
          nameToIdMap[renamedName.toLowerCase()] = targetPlaylistId;
          playlistsCount++;
          existingVideoIds = const <String>{};
          nextPosition = 1;
        } else {
          // Playlist already exists locally with the same name, merge entries
          targetPlaylistId = existingPlaylistId;
          final localEntries = await libraryRepository.getPlaylistEntries(
            targetPlaylistId,
          );
          existingVideoIds = localEntries.map((e) => e.videoId).toSet();
          nextPosition =
              localEntries.isEmpty
                  ? 1
                  : localEntries
                          .map((e) => e.position)
                          .reduce((a, b) => a > b ? a : b) +
                      1;
        }
      } else {
        // Create a new playlist
        targetPlaylistId = await libraryRepository.createPlaylistWithDate(
          playlistName,
          description: p['description'] as String?,
          createdAt: createdAt,
        );
        nameToIdMap[playlistName.toLowerCase()] = targetPlaylistId;
        playlistsCount++;
        existingVideoIds = const <String>{};
        nextPosition = 1;
      }

      // Read entries from the remote playlist
      final remoteEntries =
          (playlistEntriesRaw[oldId.toString()] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (remoteEntries.isEmpty) continue;

      for (final e in remoteEntries) {
        final videoId = e['videoId'] as String;
        if (!existingVideoIds.contains(videoId)) {
          await libraryRepository.addEntry(
            targetPlaylistId,
            videoId,
            nextPosition++,
            title: e['title'] as String?,
            artist: e['artist'] as String?,
            thumbnailUrl: e['thumbnailUrl'] as String?,
            duration: e['duration'] as int?,
            isVideo: e['isVideo'] as bool? ?? false,
            isExplicit: e['isExplicit'] as bool? ?? false,
          );
          playlistEntriesCount++;
        }
      }
    }

    // 6. Synchronize Listening History (History)
    final remoteHistory =
        (data['history'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (remoteHistory.isNotEmpty) {
      final localHistory = await libraryRepository.getRecentHistory(limit: 500);
      final historyKeys =
          localHistory
              .map((h) => '${h.videoId}_${h.playedAt.millisecondsSinceEpoch}')
              .toSet();

      for (final h in remoteHistory) {
        final playedAt = DateTime.parse(h['playedAt'] as String);
        final key = '${h['videoId']}_${playedAt.millisecondsSinceEpoch}';
        if (!historyKeys.contains(key)) {
          await libraryRepository.insertHistoryEntry(
            h['videoId'] as String,
            h['title'] as String,
            h['artist'] as String,
            thumbnailUrl: h['thumbnailUrl'] as String?,
            duration: h['duration'] as int?,
            playedAt: playedAt,
            playCount: h['playCount'] as int? ?? 1,
            isVideo: h['isVideo'] as bool? ?? false,
            isExplicit: h['isExplicit'] as bool? ?? false,
          );
          historyCount++;
        }
      }
    }

    // 7. Synchronize Recent Searches (Search History)
    final remoteSearchHistory =
        (data['searchHistory'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (remoteSearchHistory.isNotEmpty) {
      final localSearchHistory = await libraryRepository.getRecentSearches(
        limit: 100,
      );
      final searchKeys =
          localSearchHistory
              .map(
                (s) =>
                    '${s.query.toLowerCase()}_${s.searchedAt.millisecondsSinceEpoch}',
              )
              .toSet();

      for (final s in remoteSearchHistory) {
        final searchedAt = DateTime.parse(s['searchedAt'] as String);
        final query = s['query'] as String;
        final key =
            '${query.toLowerCase()}_${searchedAt.millisecondsSinceEpoch}';
        if (!searchKeys.contains(key)) {
          await libraryRepository.insertSearchEntryWithDate(
            query,
            searchedAt: searchedAt,
          );
          searchHistoryCount++;
        }
      }
    }

    return {
      'likedSongs': likedSongsCount,
      'followedArtists': followedArtistsCount,
      'likedAlbums': likedAlbumsCount,
      'likedPlaylists': likedPlaylistsCount,
      'playlists': playlistsCount,
      'playlistEntries': playlistEntriesCount,
      'history': historyCount,
      'searchHistory': searchHistoryCount,
    };
  }
}
