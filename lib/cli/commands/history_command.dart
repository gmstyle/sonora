import 'package:args/args.dart';

import '../cli_output.dart';
import '../sonora_cli_provider.dart';

class HistoryCommand {
  final SonoraCliProvider _provider;
  final bool _json;

  HistoryCommand(this._provider, this._json);

  Future<CliOutput> execute(ArgResults args) async {
    if (args['clear'] == true) {
      return _clear();
    }
    return _list(args);
  }

  Future<CliOutput> _list(ArgResults args) async {
    final limit = int.tryParse(args['limit'] as String? ?? '20') ?? 20;

    try {
      final items = await _provider.libraryRepo.getRecentHistory(limit: limit);

      if (items.isEmpty) {
        return const CliOutput('No listening history.');
      }

      final data = {
        'command': 'history',
        'results':
            items
                .map(
                  (h) => {
                    'videoId': h.videoId,
                    'title': h.title,
                    'artist': h.artist,
                    'playedAt': h.playedAt.toIso8601String(),
                    'playCount': h.playCount,
                  },
                )
                .toList(),
      };

      if (_json) return CliOutput('', data: data);

      final buf = StringBuffer()..writeln('Recent History:');
      for (var i = 0; i < items.length; i++) {
        final h = items[i];
        final date =
            '${h.playedAt.year}-${_pad(h.playedAt.month)}-${_pad(h.playedAt.day)}';
        final count = h.playCount > 1 ? ' (${h.playCount}x)' : '';
        buf.writeln('  ${i + 1}. $date — ${h.title} — ${h.artist}$count');
      }
      return CliOutput(buf.toString(), data: data);
    } catch (e) {
      return CliOutput.error('Failed to load history: $e');
    }
  }

  Future<CliOutput> _clear() async {
    try {
      await _provider.libraryRepo.clearHistory();
      return const CliOutput('Listening history cleared.');
    } catch (e) {
      return CliOutput.error('Failed to clear history: $e');
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
