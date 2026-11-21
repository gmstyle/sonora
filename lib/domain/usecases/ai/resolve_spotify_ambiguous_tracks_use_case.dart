import 'dart:convert';
import 'dart:math';

import '../../../core/constants/ai_constants.dart';
import '../../models/ask_chat_models.dart';
import '../../models/playlist_import.dart';
import '../../repositories/llm_chat_repository.dart';

const kSpotifyBatchAssistSystemInstruction = '''
You assist matching Spotify playlist tracks to YouTube Music catalog entries.
Reply with ONLY a single JSON object matching:
{
  "decisions": [
    {
      "index": 0,
      "selectedVideoId": "string or null (MUST be copied verbatim from that slot's candidates, or null)",
      "rewrittenQuery": "string or null (concise clean 'Title Artist' query if no candidate matches or candidates list is empty)"
    }
  ]
}
Rules:
- Never invent a videoId. For selectedVideoId, ONLY pick an exact videoId present in that track's candidates array, preferring studio/official audio over covers, karaoke, slowed/reverb, or unrelated live versions when duration and artist match.
- If none of the candidates match or candidates is empty, set selectedVideoId to null and provide a clean rewrittenQuery (strip remastered/feat/edition clutter).
''';

class SpotifyAssistDecision {
  const SpotifyAssistDecision({this.selectedVideoId, this.rewrittenQuery});

  final String? selectedVideoId;
  final String? rewrittenQuery;
}

/// Batch disambiguator & query rewriter for Spotify playlist imports.
///
/// Shares a single `turnId` across all chunks of one playlist so an entire
/// playlist costs at most 1 Ask credit, and strictly validates any selected
/// `videoId` against the provided candidates for that slot.
class ResolveSpotifyAmbiguousTracksUseCase {
  ResolveSpotifyAmbiguousTracksUseCase(this._chatRepository);

  final LlmChatRepository _chatRepository;
  final Random _random = Random();

  Future<Map<int, SpotifyAssistDecision>> execute(
    List<SpotifyImportSlot> slots, {
    String locale = 'en',
    bool Function()? shouldAbort,
  }) async {
    final unresolved = slots
        .where((s) => s.kind != SpotifyMatchKind.auto)
        .toList(growable: false);
    if (unresolved.isEmpty) return const {};
    if (!await _chatRepository.isReady()) return const {};

    final turnId =
        'sp_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999999)}';
    final decisions = <int, SpotifyAssistDecision>{};

    for (
      var offset = 0;
      offset < unresolved.length;
      offset += kSpotifyAssistBatchSize
    ) {
      if (shouldAbort?.call() == true) break;
      final end = min(offset + kSpotifyAssistBatchSize, unresolved.length);
      final chunk = unresolved.sublist(offset, end);

      final validIdsBySlot = <int, Set<String>>{
        for (final slot in chunk)
          slot.index: slot.reviewCandidates.map((c) => c.videoId).toSet(),
      };

      final promptPayload = {
        'tracks': [
          for (final slot in chunk)
            {
              'index': slot.index,
              'spotify': {
                'title': slot.track.title,
                'artist': slot.track.subtitle,
                if (slot.track.durationMs != null)
                  'durationSec': (slot.track.durationMs! / 1000).round(),
                'isExplicit': slot.track.isExplicit,
              },
              'candidates': [
                for (final c in slot.reviewCandidates.take(6))
                  {
                    'videoId': c.videoId,
                    'title': c.title,
                    'artist': c.artist,
                    if (c.durationSec != null) 'durationSec': c.durationSec,
                    'isExplicit': c.isExplicit,
                  },
              ],
            },
        ],
      };

      try {
        final response = await _chatRepository.completeChat(
          action: AskActionKind.spotifyMatch,
          systemInstruction: kSpotifyBatchAssistSystemInstruction,
          locale: locale,
          messages: [
            LlmChatMessage(role: 'user', content: jsonEncode(promptPayload)),
          ],
          jsonMode: true,
          maxOutputTokens: 1200,
          turnId: turnId,
        );
        final parsed = _parseDecisions(response.content, validIdsBySlot);
        decisions.addAll(parsed);
      } catch (_) {
        // Fallback gracefully to deterministic matches/review queue.
        break;
      }
    }

    return decisions;
  }

  static Map<int, SpotifyAssistDecision> _parseDecisions(
    String raw,
    Map<int, Set<String>> validIdsBySlot,
  ) {
    var text = raw.trim();
    if (text.isEmpty) return const {};
    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fence != null) {
      text = fence.group(1)!.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return const {};

    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) return const {};
      final list = decoded['decisions'];
      if (list is! List) return const {};

      final out = <int, SpotifyAssistDecision>{};
      for (final item in list) {
        if (item is! Map) continue;
        final idx = (item['index'] as num?)?.toInt();
        if (idx == null || !validIdsBySlot.containsKey(idx)) continue;

        final validIds = validIdsBySlot[idx]!;
        final rawId = item['selectedVideoId']?.toString().trim();
        final selectedId =
            (rawId != null && rawId.isNotEmpty && validIds.contains(rawId))
            ? rawId
            : null;
        final rawQuery = item['rewrittenQuery']?.toString().trim();
        final rewrittenQuery = (rawQuery != null && rawQuery.isNotEmpty)
            ? rawQuery
            : null;

        if (selectedId != null || rewrittenQuery != null) {
          out[idx] = SpotifyAssistDecision(
            selectedVideoId: selectedId,
            rewrittenQuery: rewrittenQuery,
          );
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}
