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
    final likedAlbums = await libraryRepository.getAllLikedAlbums();
    final likedPlaylists = await libraryRepository.getAllLikedPlaylists();
    final playlists = await libraryRepository.getAllPlaylists();
    final history = await libraryRepository.getRecentHistory(limit: 500);
    final searchHistory = await libraryRepository.getRecentSearches(limit: 100);

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
                  'title': e.title,
                  'artist': e.artist,
                  'thumbnailUrl': e.thumbnailUrl,
                },
              )
              .toList();
    }

    final data = <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'likedSongs':
          likedSongs
              .map(
                (s) => {
                  'videoId': s.videoId,
                  'title': s.title,
                  'artist': s.artist,
                  'thumbnailUrl': s.thumbnailUrl,
                  'artistId': s.artistId,
                  'albumId': s.albumId,
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
      'likedAlbums':
          likedAlbums
              .map(
                (a) => {
                  'albumId': a.albumId,
                  'name': a.name,
                  'artistName': a.artistName,
                  'thumbnailUrl': a.thumbnailUrl,
                  'year': a.year,
                  'addedAt': a.addedAt.toIso8601String(),
                },
              )
              .toList(),
      'likedPlaylists':
          likedPlaylists
              .map(
                (p) => {
                  'playlistId': p.playlistId,
                  'name': p.name,
                  'thumbnailUrl': p.thumbnailUrl,
                  'videoCount': p.videoCount,
                  'addedAt': p.addedAt.toIso8601String(),
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
      'history':
          history
              .map(
                (h) => {
                  'videoId': h.videoId,
                  'title': h.title,
                  'artist': h.artist,
                  'thumbnailUrl': h.thumbnailUrl,
                  'playedAt': h.playedAt.toIso8601String(),
                  'playCount': h.playCount,
                },
              )
              .toList(),
      'searchHistory':
          searchHistory
              .map(
                (s) => {
                  'query': s.query,
                  'searchedAt': s.searchedAt.toIso8601String(),
                },
              )
              .toList(),
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
