import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/artists_utils.dart';
import '../../domain/media/stream_quality_selector.dart';
import '../../domain/models/media_quality.dart';
import '../cli_output.dart';
import '../sonora_cli_provider.dart';

class DownloadCommand {
  final SonoraCliProvider _provider;

  DownloadCommand(this._provider);

  Future<CliOutput> execute(ArgResults args) async {
    final args2 = args.rest;
    if (args2.isEmpty) {
      return CliOutput.error(
        'Usage: sonora download <videoId> [--title ...] [--artist ...]',
      );
    }

    final videoId = args2[0];
    final title = args['title'] as String?;
    final artist = args['artist'] as String?;
    final outputDir = args['output-dir'] as String?;

    stderr.writeln('Resolving song info...');

    String resolvedTitle;
    String resolvedArtist;

    try {
      final song = await _provider.musicRepo.getSong(videoId);
      resolvedTitle = title ?? song.name;
      resolvedArtist = artist ?? displayArtists(song.artists);
    } catch (_) {
      if (title != null) {
        resolvedTitle = title;
        resolvedArtist = artist ?? '';
      } else {
        return CliOutput.error(
          'Could not fetch song info. Provide --title and --artist manually.',
        );
      }
    }

    stderr.writeln('Resolving stream manifest...');

    try {
      final manifest = await _provider.streamDs.getManifest(videoId);
      final stream = const StreamQualitySelector().select(
        manifest,
        quality: MediaQuality.high,
      );
      final dir = outputDir ?? Directory.current.path;
      final safeName = resolvedTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = stream.container.name;
      final filePath = p.join(dir, '$safeName-$videoId.$ext');

      stderr.writeln('Downloading "$resolvedTitle" — $resolvedArtist');
      stderr.writeln('Format: ${stream.tag} ($ext)');
      stderr.writeln('Saving to: $filePath');

      await _provider.streamDs.downloadStreamToFile(
        stream,
        filePath,
        onProgress: (received, total) {
          if (total > 0) {
            final percent = (received / total * 100).toStringAsFixed(1);
            stderr.write('\rProgress: $percent%   ');
          }
        },
      );
      stderr.writeln('\nDownload complete: $filePath');

      await _provider.libraryRepo.insertDownload(
        videoId: videoId,
        title: resolvedTitle,
        artist: resolvedArtist,
        status: 'completed',
        localPath: filePath,
        format: ext,
        fileSize: await File(filePath).length(),
        downloadedAt: DateTime.now(),
      );

      final data = {
        'command': 'download',
        'videoId': videoId,
        'title': resolvedTitle,
        'path': filePath,
      };
      return CliOutput('Downloaded to $filePath', data: data);
    } catch (e) {
      return CliOutput.error('Download failed: $e');
    }
  }
}
