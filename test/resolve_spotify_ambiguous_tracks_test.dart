import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/playlist_import.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';
import 'package:sonora/domain/usecases/ai/resolve_spotify_ambiguous_tracks_use_case.dart';

class _FakeSpotifyBatchRepo implements LlmChatRepository {
  _FakeSpotifyBatchRepo(this.handler, {this.ready = true});

  final bool ready;
  final Future<LlmChatResponse> Function(
    List<LlmChatMessage> messages,
    String? turnId,
  )
  handler;

  final List<String?> turnIds = [];

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<AskQuotaInfo?> fetchQuota() async => AskQuotaInfo.unlimited();

  @override
  Future<LlmChatResponse> completeChat({
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    String? systemInstruction,
    String locale = 'en',
    List<LlmToolDefinition> tools = const [],
    String? toolChoice,
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  }) {
    expect(action, AskActionKind.spotifyMatch);
    turnIds.add(turnId);
    return handler(messages, turnId);
  }
}

SpotifyImportSlot _reviewSlot(int index, String title) {
  return SpotifyImportSlot(
    index: index,
    track: SpotifyPlaylistTrack(title: title, subtitle: 'Artist $index'),
    kind: SpotifyMatchKind.needsReview,
    reviewCandidates: [
      ImportedTrackCandidate(
        videoId: 'cand_${index}_a',
        title: title,
        artist: 'Artist $index',
        durationSec: 200,
      ),
      ImportedTrackCandidate(
        videoId: 'cand_${index}_b',
        title: '$title (Karaoke)',
        artist: 'Cover Band',
        durationSec: 200,
      ),
    ],
  );
}

SpotifyImportSlot _noneSlot(int index, String title) {
  return SpotifyImportSlot(
    index: index,
    track: SpotifyPlaylistTrack(
      title: '$title - Remastered 2011 (feat. Guest)',
      subtitle: 'Artist $index',
    ),
    kind: SpotifyMatchKind.none,
  );
}

void main() {
  group('ResolveSpotifyAmbiguousTracksUseCase', () {
    test('promotes verified candidate IDs, ignores hallucinated IDs, rewrites none queries, and shares 1 turnId across chunks', () async {
      // 14 unresolved tracks -> 2 chunks (12 + 2) sharing ONE turnId.
      final slots = [
        const SpotifyImportSlot(
          index: 0,
          track: SpotifyPlaylistTrack(title: 'Auto Song', subtitle: 'A'),
          kind: SpotifyMatchKind.auto,
          candidate: ImportedTrackCandidate(
            videoId: 'auto_0',
            title: 'Auto Song',
            artist: 'A',
          ),
        ),
        for (var i = 1; i <= 12; i++) _reviewSlot(i, 'Track $i'),
        _reviewSlot(13, 'Hallucinated Track'),
        _noneSlot(14, 'Clean Me'),
      ];

      final repo = _FakeSpotifyBatchRepo((messages, turnId) async {
        final payload =
            jsonDecode(messages.single.content!) as Map<String, dynamic>;
        final sentTracks = payload['tracks'] as List;
        final decisions = <Map<String, dynamic>>[];
        for (final item in sentTracks) {
          final idx = (item as Map)['index'] as int;
          if (idx <= 12) {
            decisions.add({
              'index': idx,
              'selectedVideoId': 'cand_${idx}_a',
              'rewrittenQuery': null,
            });
          } else if (idx == 13) {
            decisions.add({
              'index': 13,
              'selectedVideoId': 'INVENTED_NOT_IN_CANDIDATES',
              'rewrittenQuery': 'Track 13 Artist 13',
            });
          } else if (idx == 14) {
            decisions.add({
              'index': 14,
              'selectedVideoId': null,
              'rewrittenQuery': 'Clean Me Artist 14',
            });
          }
        }
        return LlmChatResponse(content: jsonEncode({'decisions': decisions}));
      });

      final uc = ResolveSpotifyAmbiguousTracksUseCase(repo);
      final out = await uc.execute(slots);

      expect(repo.turnIds, hasLength(2));
      expect(repo.turnIds[0], isNotNull);
      expect(repo.turnIds[0], repo.turnIds[1]);

      expect(out.containsKey(0), isFalse);
      expect(out[1]?.selectedVideoId, 'cand_1_a');
      expect(out[12]?.selectedVideoId, 'cand_12_a');
      // Index 13 hallucinated ID dropped, clean rewrittenQuery preserved.
      expect(out[13]?.selectedVideoId, isNull);
      expect(out[13]?.rewrittenQuery, 'Track 13 Artist 13');
      expect(out[14]?.rewrittenQuery, 'Clean Me Artist 14');
    });

    test('falls back cleanly when Ask throws or is not ready', () async {
      final repo = _FakeSpotifyBatchRepo((_, _) async {
        throw const AskQuotaExceededException(
          AskQuotaInfo(remaining: 0, limit: 30),
        );
      });
      final uc = ResolveSpotifyAmbiguousTracksUseCase(repo);
      final out = await uc.execute([_reviewSlot(0, 'A')]);
      expect(out, isEmpty);

      final notReadyRepo = _FakeSpotifyBatchRepo(
        (_, _) async => const LlmChatResponse(),
        ready: false,
      );
      final notReadyUc = ResolveSpotifyAmbiguousTracksUseCase(notReadyRepo);
      expect(await notReadyUc.execute([_reviewSlot(0, 'A')]), isEmpty);
    });
  });
}
