// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';

import 'package:sonora/cli/cli_output.dart';
import 'package:sonora/cli/commands/download_command.dart';
import 'package:sonora/cli/commands/history_command.dart';
import 'package:sonora/cli/commands/library_command.dart';
import 'package:sonora/cli/commands/play_command.dart';
import 'package:sonora/cli/commands/search_command.dart';
import 'package:sonora/cli/sonora_cli_provider.dart';

Future<void> main(List<String> arguments) async {
  final parser =
      ArgParser()
        ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false);

  final subcommands = <String, ArgParser>{
    'search':
        ArgParser()
          ..addOption(
            'type',
            abbr: 't',
            help: 'Filter (song/album/artist/playlist/video)',
          )
          ..addOption('limit', abbr: 'l', help: 'Max results', defaultsTo: '10')
          ..addFlag('json', help: 'JSON output', negatable: false)
          ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false),

    'play':
        ArgParser()
          ..addOption(
            'player',
            help: 'Player (auto/mpv/ffplay/url)',
            defaultsTo: 'auto',
          )
          ..addFlag('json', help: 'JSON output', negatable: false, hide: true)
          ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false),

    'library':
        ArgParser()
          ..addOption('type', help: 'Type (songs/albums/artists/playlists)')
          ..addOption('id', help: 'Item ID')
          ..addOption('title', help: 'Item title')
          ..addOption('artist', help: 'Artist name')
          ..addFlag('json', help: 'JSON output', negatable: false)
          ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false),

    'download':
        ArgParser()
          ..addOption('title', help: 'Song title')
          ..addOption('artist', help: 'Artist name')
          ..addOption('output-dir', help: 'Download directory')
          ..addFlag('json', help: 'JSON output', negatable: false, hide: true)
          ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false),

    'history':
        ArgParser()
          ..addOption('limit', abbr: 'l', help: 'Max entries', defaultsTo: '20')
          ..addFlag('clear', help: 'Clear history', negatable: false)
          ..addFlag('json', help: 'JSON output', negatable: false)
          ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false),
  };

  if (arguments.isEmpty) {
    _printUsage(parser, subcommands);
    return;
  }

  final command = arguments[0];

  if (command == '--help' || command == '-h') {
    _printUsage(parser, subcommands);
    return;
  }

  if (!subcommands.containsKey(command)) {
    stderr.writeln('Unknown command: $command');
    _printUsage(parser, subcommands);
    exitCode = 1;
    return;
  }

  final subParser = subcommands[command]!;
  final subArgs = arguments.length > 1 ? arguments.sublist(1) : <String>[];

  ArgResults results;
  try {
    results = subParser.parse(subArgs);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 1;
    return;
  }

  if (results['help'] == true) {
    stderr.writeln('sonora $command [options]\n');
    stderr.writeln(subParser.usage);
    return;
  }

  final useJson = results['json'] as bool? ?? false;

  final provider = SonoraCliProvider();
  try {
    stderr.writeln('Initializing...');
    await provider.initialize();
    stderr.writeln('Ready.\n');
  } catch (e) {
    stderr.writeln('Initialization failed: $e');
    exitCode = 1;
    return;
  }

  CliOutput output;
  try {
    switch (command) {
      case 'search':
        output = await SearchCommand(provider, useJson).execute(results);
      case 'play':
        output = await PlayCommand(provider).execute(results);
      case 'download':
        output = await DownloadCommand(provider).execute(results);
      case 'library':
        output = await LibraryCommand(provider, useJson).execute(results);
      case 'history':
        output = await HistoryCommand(provider, useJson).execute(results);
      default:
        output = CliOutput.error('Unknown command: $command');
    }
  } catch (e) {
    output = CliOutput.error('Error: $e');
  }

  if (useJson && output.data != null) {
    print(output.toJson());
  } else {
    print(output.toText());
  }

  await provider.dispose();
  exitCode = output.exitCode;
}

void _printUsage(ArgParser parser, Map<String, ArgParser> subcommands) {
  stderr.writeln('Usage: sonora <command> [options]\n');
  stderr.writeln('Commands:');
  for (final cmd in subcommands.keys) {
    stderr.writeln('  $cmd');
  }
  stderr.writeln('\nOptions:');
  stderr.writeln(parser.usage);
  stderr.writeln();
  stderr.writeln('See "sonora <command> --help" for command-specific options.');
}
