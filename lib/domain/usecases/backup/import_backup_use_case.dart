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
        (data['followedArtists'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final playlistsRaw =
        (data['playlists'] as List<dynamic>).cast<Map<String, dynamic>>();
    final settings = data['settings'] as Map<String, dynamic>?;

    for (final s in likedSongs) {
      await libraryRepository.toggleLikedSong(
        LikedSongModel(
          videoId: s['videoId'] as String,
          title: s['title'] as String,
          artist: s['artist'] as String,
          thumbnailUrl: s['thumbnailUrl'] as String?,
          addedAt: DateTime.parse(s['addedAt'] as String),
        ),
      );
    }

    for (final a in followedArtists) {
      await libraryRepository.toggleFollowedArtist(
        FollowedArtistModel(
          artistId: a['artistId'] as String,
          name: a['name'] as String,
          thumbnailUrl: a['thumbnailUrl'] as String?,
        ),
      );
    }

    for (final p in playlistsRaw) {
      await libraryRepository.createPlaylist(
        p['name'] as String,
        description: p['description'] as String?,
      );
    }

    return settings;
  }
}
