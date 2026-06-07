import 'package:args/args.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../cli_output.dart';
import '../sonora_cli_provider.dart';

class SearchCommand {
  final SonoraCliProvider _provider;
  final bool _json;

  SearchCommand(this._provider, this._json);

  Future<CliOutput> execute(ArgResults args) async {
    final query = args.rest.join(' ');
    if (query.isEmpty) {
      return CliOutput.error(
        'Usage: sonora search <query> [--type song|album|artist|playlist|video] [--limit N]',
      );
    }

    final type = args['type'] as String?;
    final limit = int.tryParse(args['limit'] as String? ?? '10') ?? 10;

    final validTypes = ['song', 'album', 'artist', 'playlist', 'video'];
    if (type != null && !validTypes.contains(type)) {
      return CliOutput.error(
        'Invalid type: $type. Use: ${validTypes.join(", ")}',
      );
    }

    try {
      if (type == null || type == 'song') {
        final songs = await _provider.musicRepo.searchSongs(query);
        return _formatSongs(songs.take(limit).toList());
      }
      if (type == 'album') {
        final albums = await _provider.musicRepo.searchAlbums(query);
        return _formatAlbums(albums.take(limit).toList());
      }
      if (type == 'artist') {
        final artists = await _provider.musicRepo.searchArtists(query);
        return _formatArtists(artists.take(limit).toList());
      }
      if (type == 'playlist') {
        final playlists = await _provider.musicRepo.searchPlaylists(query);
        return _formatPlaylists(playlists.take(limit).toList());
      }
      if (type == 'video') {
        final videos = await _provider.musicRepo.searchVideos(query);
        return _formatVideos(videos.take(limit).toList());
      }
      return const CliOutput('No results.');
    } catch (e) {
      return CliOutput.error('Search failed: $e');
    }
  }

  CliOutput _formatSongs(List<SongDetailed> items) {
    if (items.isEmpty) return const CliOutput('No songs found.');
    final data = {
      'command': 'search',
      'type': 'song',
      'results':
          items
              .map(
                (s) => {
                  'videoId': s.videoId,
                  'title': s.name,
                  'artist': s.artist.name,
                  'album': s.album?.name,
                  'duration': s.duration,
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Songs:');
    for (var i = 0; i < items.length; i++) {
      buf.writeln(
        '  ${i + 1}. ${items[i].name} \u2014 ${items[i].artist.name}',
      );
      buf.writeln('     ID: ${items[i].videoId}');
    }
    buf.writeln('\nUse "sonora play <videoId>" to play a song.');
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatAlbums(List<AlbumDetailed> items) {
    if (items.isEmpty) return const CliOutput('No albums found.');
    final data = {
      'command': 'search',
      'type': 'album',
      'results':
          items
              .map(
                (a) => {
                  'albumId': a.albumId,
                  'title': a.name,
                  'artist': a.artist.name,
                  'year': a.year,
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Albums:');
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final year = a.year != null ? ' (${a.year})' : '';
      buf.writeln('  ${i + 1}. ${a.name} \u2014 ${a.artist.name}$year');
      buf.writeln('     ID: ${a.albumId}');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatArtists(List<ArtistDetailed> items) {
    if (items.isEmpty) return const CliOutput('No artists found.');
    final data = {
      'command': 'search',
      'type': 'artist',
      'results':
          items
              .map(
                (a) => {
                  'artistId': a.artistId,
                  'name': a.name,
                  'monthlyListeners': a.monthlyListeners,
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Artists:');
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final listeners =
          a.monthlyListeners != null
              ? ' (${a.monthlyListeners} monthly listeners)'
              : '';
      buf.writeln('  ${i + 1}. ${a.name}$listeners');
      buf.writeln('     ID: ${a.artistId}');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatPlaylists(List<PlaylistDetailed> items) {
    if (items.isEmpty) return const CliOutput('No playlists found.');
    final data = {
      'command': 'search',
      'type': 'playlist',
      'results':
          items
              .map(
                (p) => {
                  'playlistId': p.playlistId,
                  'title': p.name,
                  'artist': p.artist.name,
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Playlists:');
    for (var i = 0; i < items.length; i++) {
      buf.writeln(
        '  ${i + 1}. ${items[i].name} \u2014 ${items[i].artist.name}',
      );
      buf.writeln('     ID: ${items[i].playlistId}');
    }
    return CliOutput(buf.toString(), data: data);
  }

  CliOutput _formatVideos(List<VideoDetailed> items) {
    if (items.isEmpty) return const CliOutput('No videos found.');
    final data = {
      'command': 'search',
      'type': 'video',
      'results':
          items
              .map(
                (v) => {
                  'videoId': v.videoId,
                  'title': v.name,
                  'artist': v.artist.name,
                  'views': v.viewCount,
                },
              )
              .toList(),
    };
    if (_json) return CliOutput('', data: data);
    final buf = StringBuffer()..writeln('Videos:');
    for (var i = 0; i < items.length; i++) {
      final v = items[i];
      final views = v.viewCount != null ? ' (${v.viewCount} views)' : '';
      buf.writeln('  ${i + 1}. ${v.name} \u2014 ${v.artist.name}$views');
      buf.writeln('     ID: ${v.videoId}');
    }
    return CliOutput(buf.toString(), data: data);
  }
}
