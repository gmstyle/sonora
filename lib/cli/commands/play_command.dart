import 'dart:io';

import 'package:args/args.dart';

import '../cli_output.dart';
import '../sonora_cli_provider.dart';
import '../../core/utils/artists_utils.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/usecases/player/play_video_id_use_case.dart';

class PlayCommand {
  final SonoraCliProvider _provider;

  PlayCommand(this._provider);

  Future<CliOutput> execute(ArgResults args) async {
    if (args.rest.isEmpty) {
      return CliOutput.error(
        'Usage: sonora play <videoId> [--player mpv|ffplay|url]',
      );
    }

    final videoId = args.rest[0];
    final player = args['player'] as String? ?? 'auto';

    try {
      stderr.writeln('Resolving "$videoId"...');
      var url = await resolveCompletedDownloadUrl(
        videoId,
        _provider.libraryRepo,
      );
      if (url == null) {
        await _provider.initializeRemote();
        url = await PlayVideoIdUseCase(
          _provider.musicRepo,
          _provider.libraryRepo,
        ).resolveUrl(videoId);
      }
      final meta = await resolveCliPlayMetadata(
        videoId: videoId,
        libraryRepo: _provider.libraryRepo,
        musicRepo: _provider.isRemoteReady ? _provider.musicRepo : null,
      );
      final title = meta.title;
      final artist = meta.artist;

      stderr.writeln('$title — $artist');
      stderr.writeln();

      final data = {
        'command': 'play',
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'streamUrl': url,
      };

      if (player == 'url') {
        return CliOutput(url, data: data);
      }

      final resolved = _resolvePlayer(player);
      if (resolved == null) {
        stderr.writeln('No suitable player found. Stream URL:');
        return CliOutput(url, data: data);
      }

      stderr.writeln('Playing with ${resolved.name}...');
      stderr.writeln('Press Ctrl+C to stop.');

      final result = await Process.run(resolved.path, [...resolved.args, url]);

      if (result.exitCode != 0) {
        return CliOutput.error(
          'Player exited with code ${result.exitCode}: ${result.stderr}',
          data: data,
        );
      }

      return const CliOutput('Playback finished.');
    } catch (e) {
      if (e is ProcessException) {
        return CliOutput.error(
          'Player not found. Install mpv or ffplay, or use --player url.',
        );
      }
      return CliOutput.error('Playback failed: $e');
    }
  }

  _Player? _resolvePlayer(String preference) {
    if (preference == 'auto') {
      return _findPlayer(['mpv', 'ffplay', 'vlc']);
    }
    return _findPlayer([preference]);
  }

  _Player? _findPlayer(List<String> candidates) {
    for (final name in candidates) {
      final which = Process.runSync('which', [name]);
      if (which.exitCode == 0) {
        final path = (which.stdout as String).toString().trim();
        return _Player(name, path, _argsFor(name));
      }
    }
    return null;
  }

  List<String> _argsFor(String player) {
    switch (player) {
      case 'mpv':
        return ['--no-video', '--quiet'];
      case 'ffplay':
        return ['-nodisp', '-autoexit', '-loglevel', 'quiet'];
      case 'vlc':
        return ['--intf', 'dummy', '--play-and-exit', '--no-video'];
      default:
        return [];
    }
  }
}

class _Player {
  final String name;
  final String path;
  final List<String> args;

  const _Player(this.name, this.path, this.args);
}

/// Title/artist for `sonora play`. Prefers a completed download so playback
/// can stay offline after [PlayVideoIdUseCase.resolveUrl] has already
/// succeeded with a local file.
Future<({String title, String artist})> resolveCliPlayMetadata({
  required String videoId,
  required LibraryRepository libraryRepo,
  MusicRepository? musicRepo,
}) async {
  try {
    final download = await libraryRepo.getDownload(videoId);
    if (download != null &&
        download.status == 'completed' &&
        download.title.isNotEmpty) {
      return (title: download.title, artist: download.artist);
    }
  } catch (_) {}

  if (musicRepo == null) {
    return (title: videoId, artist: '');
  }

  try {
    final song = await musicRepo.getSong(videoId);
    return (title: song.name, artist: displayArtists(song.artists));
  } catch (_) {
    return (title: videoId, artist: '');
  }
}
