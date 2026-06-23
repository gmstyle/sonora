import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../models/library_models.dart';
import '../../repositories/library_repository.dart';

class ImportBackupUseCase {
  final LibraryRepository libraryRepository;

  ImportBackupUseCase(this.libraryRepository);

  Future<Map<String, dynamic>?> execute(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.files.firstWhere((f) => f.name == 'backup.json');
    final content = utf8.decode(file.content as List<int>);
    final data = jsonDecode(content) as Map<String, dynamic>;

    final likedSongs =
        (data['likedSongs'] as List<dynamic>).cast<Map<String, dynamic>>();
    final followedArtists =
        (data['followedArtists'] as List<dynamic>).cast<Map<String, dynamic>>();
    final likedAlbums =
        (data['likedAlbums'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    final likedPlaylists =
        (data['likedPlaylists'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final playlistsRaw =
        (data['playlists'] as List<dynamic>).cast<Map<String, dynamic>>();
    final playlistEntriesRaw =
        data['playlistEntries'] as Map<String, dynamic>? ?? {};
    final history =
        (data['history'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final searchHistory =
        (data['searchHistory'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final settings = data['settings'] as Map<String, dynamic>?;

    for (final s in likedSongs) {
      await libraryRepository.ensureLikedSong(
        LikedSongModel(
          videoId: s['videoId'] as String,
          title: s['title'] as String,
          artist: s['artist'] as String,
          thumbnailUrl: s['thumbnailUrl'] as String?,
          artistId: s['artistId'] as String?,
          albumId: s['albumId'] as String?,
          addedAt: DateTime.parse(s['addedAt'] as String),
        ),
      );
    }

    for (final a in followedArtists) {
      await libraryRepository.ensureFollowedArtist(
        FollowedArtistModel(
          artistId: a['artistId'] as String,
          name: a['name'] as String,
          thumbnailUrl: a['thumbnailUrl'] as String?,
          addedAt:
              a['addedAt'] != null
                  ? DateTime.parse(a['addedAt'] as String)
                  : DateTime.now(),
        ),
      );
    }

    for (final a in likedAlbums) {
      await libraryRepository.ensureLikedAlbum(
        LikedAlbumModel(
          albumId: a['albumId'] as String,
          name: a['name'] as String,
          artistName: a['artistName'] as String,
          thumbnailUrl: a['thumbnailUrl'] as String?,
          year: a['year'] as int?,
          addedAt: DateTime.parse(a['addedAt'] as String),
        ),
      );
    }

    for (final p in likedPlaylists) {
      await libraryRepository.ensureLikedPlaylist(
        LikedPlaylistModel(
          playlistId: p['playlistId'] as String,
          name: p['name'] as String,
          thumbnailUrl: p['thumbnailUrl'] as String?,
          videoCount: p['videoCount'] as int?,
          addedAt: DateTime.parse(p['addedAt'] as String),
        ),
      );
    }

    final oldToNewId = <int, int>{};
    for (final p in playlistsRaw) {
      final oldId = p['id'] as int;
      final createdAt =
          p['createdAt'] != null
              ? DateTime.tryParse(p['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();
      final newId = await libraryRepository.createPlaylistWithDate(
        p['name'] as String,
        description: p['description'] as String?,
        createdAt: createdAt,
      );
      oldToNewId[oldId] = newId;
    }

    for (final entry in oldToNewId.entries) {
      final oldId = entry.key;
      final newId = entry.value;
      final entries =
          (playlistEntriesRaw[oldId.toString()] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      for (final e in entries) {
        await libraryRepository.addEntry(
          newId,
          e['videoId'] as String,
          e['position'] as int,
          title: e['title'] as String?,
          artist: e['artist'] as String?,
          thumbnailUrl: e['thumbnailUrl'] as String?,
        );
      }
    }

    for (final h in history) {
      await libraryRepository.insertHistoryEntry(
        h['videoId'] as String,
        h['title'] as String,
        h['artist'] as String,
        thumbnailUrl: h['thumbnailUrl'] as String?,
        playedAt: DateTime.parse(h['playedAt'] as String),
        playCount: h['playCount'] as int? ?? 1,
        isVideo: h['isVideo'] as bool? ?? false,
      );
    }

    for (final s in searchHistory) {
      await libraryRepository.insertSearchEntryWithDate(
        s['query'] as String,
        searchedAt: DateTime.parse(s['searchedAt'] as String),
      );
    }

    return settings;
  }
}
