import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../repositories/library_repository.dart';

class ExportBackupUseCase {
  final LibraryRepository libraryRepository;

  ExportBackupUseCase(this.libraryRepository);

  Future<String> execute({Map<String, dynamic>? settings}) async {
    final likedSongs = await libraryRepository.getAllLikedSongs();
    final followedArtists = await libraryRepository.getAllFollowedArtists();
    final playlists = await libraryRepository.getAllPlaylists();

    final playlistEntries = <String, List<Map<String, dynamic>>>{};
    for (final p in playlists) {
      final entries = await libraryRepository.getPlaylistEntries(p.id);
      playlistEntries[p.id.toString()] =
          entries
              .map(
                (e) => {
                  'playlistId': e.playlistId,
                  'videoId': e.videoId,
                  'position': e.position,
                },
              )
              .toList();
    }

    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'likedSongs':
          likedSongs
              .map(
                (s) => {
                  'videoId': s.videoId,
                  'title': s.title,
                  'artist': s.artist,
                  'thumbnailUrl': s.thumbnailUrl,
                  'addedAt': s.addedAt.toIso8601String(),
                },
              )
              .toList(),
      'followedArtists':
          followedArtists
              .map(
                (a) => {
                  'artistId': a.artistId,
                  'name': a.name,
                  'thumbnailUrl': a.thumbnailUrl,
                },
              )
              .toList(),
      'playlists':
          playlists
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'description': p.description,
                  'createdAt': p.createdAt.toIso8601String(),
                },
              )
              .toList(),
      'playlistEntries': playlistEntries,
      'settings': settings,
    };

    final jsonString = jsonEncode(data);
    final jsonBytes = utf8.encode(jsonString);

    final archive = Archive();
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));
    final compressed = ZipEncoder().encode(archive);

    final tempDir = Directory.systemTemp;
    final outputPath =
        '${tempDir.path}/sonora_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    await File(outputPath).writeAsBytes(compressed);

    return outputPath;
  }
}
