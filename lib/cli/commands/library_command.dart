import 'package:args/args.dart';

import '../../domain/models/library_models.dart';
import '../cli_output.dart';
import '../sonora_cli_provider.dart';

class LibraryCommand {
  final SonoraCliProvider _provider;
  final bool _json;

  LibraryCommand(this._provider, this._json);

  Future<CliOutput> execute(ArgResults args) async {
    final subcommand = args.rest.isNotEmpty ? args.rest[0] : 'list';
    final type = args['type'] as String? ?? 'songs';

    switch (subcommand) {
      case 'list':
        return _list(type);
      case 'add':
        return _add(args);
      case 'remove':
        return _remove(args);
      default:
        return CliOutput.error(
          'Unknown library subcommand: $subcommand. Use: list, add, remove',
        );
    }
  }

  Future<CliOutput> _list(String type) async {
    try {
      switch (type) {
        case 'songs':
          final items = await _provider.libraryRepo.getAllLikedSongs();
          return _formatSongs(items);
        case 'albums':
          final items = await _provider.libraryRepo.getAllLikedAlbums();
          return _formatAlbums(items);
        case 'artists':
          final items = await _provider.libraryRepo.getAllFollowedArtists();
          return _formatArtists(items);
        case 'playlists':
          final items = await _provider.libraryRepo.getAllLikedPlaylists();
          return _formatPlaylists(items);
        default:
          return CliOutput.error(
            'Invalid type: $type. Use: songs, albums, artists, playlists',
          );
      }
    } catch (e) {
      return CliOutput.error('Failed to list library: $e');
    }
  }

  Future<CliOutput> _add(ArgResults args) async {
    final type = args['type'] as String?;
    final id = args['id'] as String?;
    if (type == null || id == null) {
      return CliOutput.error(
        'Usage: sonora library add --type song|album|artist|playlist --id <id> [--title ...] [--artist ...]',
      );
    }

    final title = args['title'] as String? ?? id;
    final artist = args['artist'] as String? ?? '';

    try {
      switch (type) {
        case 'song':
          await _provider.libraryRepo.ensureLikedSong(
            LikedSongModel(
              videoId: id,
              title: title,
              artist: artist,
              addedAt: DateTime.now(),
            ),
          );
          return CliOutput.success('Added song "$title" to library.');
        case 'album':
          await _provider.libraryRepo.ensureLikedAlbum(
            LikedAlbumModel(
              albumId: id,
              name: title,
              artistName: artist,
              addedAt: DateTime.now(),
            ),
          );
          return CliOutput.success('Added album "$title" to library.');
        case 'artist':
          await _provider.libraryRepo.ensureFollowedArtist(
            FollowedArtistModel(
              artistId: id,
              name: title,
              addedAt: DateTime.now(),
            ),
          );
          return CliOutput.success('Followed artist "$title".');
        case 'playlist':
          await _provider.libraryRepo.ensureLikedPlaylist(
            LikedPlaylistModel(
              playlistId: id,
              name: title,
              addedAt: DateTime.now(),
            ),
          );
          return CliOutput.success('Added playlist "$title" to library.');
        default:
          return CliOutput.error('Invalid type: $type');
      }
    } catch (e) {
      return CliOutput.error('Failed to add to library: $e');
    }
  }

  Future<CliOutput> _remove(ArgResults args) async {
    final type = args['type'] as String?;
    final id = args['id'] as String?;
    if (type == null || id == null) {
      return CliOutput.error(
        'Usage: sonora library remove --type song|album|artist|playlist --id <id>',
      );
    }

    try {
      switch (type) {
        case 'song':
          await _provider.libraryRepo.deleteLikedSong(id);
          return CliOutput.success('Removed song from library.');
        case 'album':
          await _provider.libraryRepo.deleteLikedAlbum(id);
          return CliOutput.success('Removed album from library.');
        case 'artist':
          await _provider.libraryRepo.deleteFollowedArtist(id);
          return CliOutput.success('Unfollowed artist.');
        case 'playlist':
          await _provider.libraryRepo.deleteLikedPlaylist(id);
          return CliOutput.success('Removed playlist from library.');
        default:
          return CliOutput.error('Invalid type: $type');
      }
    } catch (e) {
      return CliOutput.error('Failed to remove from library: $e');
    }
  }

  CliOutput _formatSongs(List<LikedSongModel> items) {
    if (items.isEmpty) return const CliOutput('No songs in library.');
    final data = {
      'command': 'library',
      'type': 'songs',
      'results':
          items
              .map(
                (s) => {
                  'videoId': s.videoId,
                  'title': s.title,
                  'artist': s.artist,
                  'addedAt': s.addedAt.toIso8601String(),
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Liked Songs:');
    for (var i = 0; i < items.length; i++) {
      buf.writeln('  ${i + 1}. ${items[i].title} — ${items[i].artist}');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatAlbums(List<LikedAlbumModel> items) {
    if (items.isEmpty) return const CliOutput('No albums in library.');
    final data = {
      'command': 'library',
      'type': 'albums',
      'results':
          items
              .map(
                (a) => {
                  'albumId': a.albumId,
                  'title': a.name,
                  'artist': a.artistName,
                  'year': a.year,
                  'addedAt': a.addedAt.toIso8601String(),
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Liked Albums:');
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final year = a.year != null ? ' (${a.year})' : '';
      buf.writeln('  ${i + 1}. ${a.name} — ${a.artistName}$year');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatArtists(List<FollowedArtistModel> items) {
    if (items.isEmpty) return const CliOutput('No artists in library.');
    final data = {
      'command': 'library',
      'type': 'artists',
      'results':
          items
              .map(
                (a) => {
                  'artistId': a.artistId,
                  'name': a.name,
                  'addedAt': a.addedAt.toIso8601String(),
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Followed Artists:');
    for (var i = 0; i < items.length; i++) {
      buf.writeln('  ${i + 1}. ${items[i].name}');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatPlaylists(List<LikedPlaylistModel> items) {
    if (items.isEmpty) return const CliOutput('No playlists in library.');
    final data = {
      'command': 'library',
      'type': 'playlists',
      'results':
          items
              .map(
                (p) => {
                  'playlistId': p.playlistId,
                  'title': p.name,
                  'videoCount': p.videoCount,
                  'addedAt': p.addedAt.toIso8601String(),
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Liked Playlists:');
    for (var i = 0; i < items.length; i++) {
      final p = items[i];
      final count = p.videoCount != null ? ' (${p.videoCount} tracks)' : '';
      buf.writeln('  ${i + 1}. ${p.name}$count');
    }
    return CliOutput(buf.toString(), data: data);
  }
}
