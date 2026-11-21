import 'dart:convert';

import '../../models/ask_chat_models.dart';
import '../../repositories/ask_storage_repository.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/llm_chat_repository.dart';

const kPulseDropSystemInstruction = '''
You generate a short proactive music discovery card for a Sonora user.
Reply with ONLY a single JSON object:
{
  "title": "string (max 55 chars, catchy, warm & informal)",
  "body": "string (max 140 chars, casual music-friend tone using only the provided facts; informal 'tu' in Italian)",
  "starterPrompt": "string (max 120 chars, natural first-person prompt for Sonora Ask)"
}
Rules:
- Mention ONLY artists or songs present in the user facts.
- Never invent IDs, URLs, or facts.
- Never mention AI, models, or DeepSeek.
''';

/// Inspects local listening patterns (heavy rotation, forgotten favorites,
/// taste growth) and asks DeepSeek (`pulse_drop`, 0 daily user credits) for a
/// personalized proactive discovery card at most once every 48 hours.
class EvaluateProactiveDropsUseCase {
  EvaluateProactiveDropsUseCase(
    this._library,
    this._storage,
    this._chatRepository, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LibraryRepository _library;
  final AskStorageRepository _storage;
  final LlmChatRepository _chatRepository;
  final DateTime Function() _now;

  static const Duration _cooldown = Duration(hours: 48);

  Future<AskProactiveDrop?> execute({required String locale}) async {
    final now = _now();
    final active = await _storage.getActiveDrops();
    if (active.any((d) => now.difference(d.createdAt) < _cooldown)) {
      return null;
    }
    if (!await _chatRepository.isReady()) return null;

    final usedSeeds = active
        .map((d) => d.seedId)
        .whereType<String>()
        .map((s) => s.toLowerCase())
        .toSet();

    final signal = await _detectSignal(usedSeeds);
    if (signal == null) return null;

    try {
      final response = await _chatRepository.completeChat(
        action: AskActionKind.pulseDrop,
        systemInstruction: kPulseDropSystemInstruction,
        locale: locale,
        jsonMode: true,
        maxOutputTokens: 220,
        messages: [
          LlmChatMessage(
            role: 'user',
            content: jsonEncode({
              'locale': locale,
              'signalKind': signal.kind,
              ...signal.facts,
            }),
          ),
        ],
      );
      final parsed = _parseDropPayload(response.content);
      if (parsed == null) return null;

      final drop = AskProactiveDrop(
        id: 'drop_${now.millisecondsSinceEpoch}',
        kind: signal.kind,
        title: parsed.$1,
        body: parsed.$2,
        starterPrompt: parsed.$3,
        seedId: signal.seedId,
        createdAt: now,
      );
      await _storage.upsertDrop(drop);
      return drop;
    } catch (_) {
      return null;
    }
  }

  Future<_DropSignal?> _detectSignal(Set<String> usedSeeds) async {
    final history = await _library.getRecentHistory(limit: 40);
    final artistCounts = <String, int>{};
    for (final h in history) {
      final artist = h.artist.trim();
      if (artist.isEmpty) continue;
      artistCounts[artist] = (artistCounts[artist] ?? 0) + h.playCount;
    }
    final rankedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in rankedArtists) {
      if (entry.value < 4) break;
      final seed = 'heavy:${entry.key.toLowerCase()}';
      if (usedSeeds.contains(seed)) continue;
      final topSongs = history
          .where((h) => h.artist.trim() == entry.key)
          .take(3)
          .map((h) => h.title)
          .toList(growable: false);
      return _DropSignal(
        kind: 'heavy_rotation',
        seedId: seed,
        facts: {
          'artist': entry.key,
          'plays': entry.value,
          'recentTracks': topSongs,
        },
      );
    }

    final forgotten = await _library.getForgottenFavorites(daysLimit: 30);
    if (forgotten.length >= 3 && !usedSeeds.contains('forgotten_favorites')) {
      return _DropSignal(
        kind: 'forgotten_favorites',
        seedId: 'forgotten_favorites',
        facts: {
          'count': forgotten.length,
          'sampleTracks': [
            for (final s in forgotten.take(3)) '${s.title} - ${s.artist}',
          ],
        },
      );
    }

    final liked = await _library.getAllLikedSongs();
    if (liked.length + history.length >= 5 &&
        !usedSeeds.contains('taste_discovery')) {
      return _DropSignal(
        kind: 'taste_discovery',
        seedId: 'taste_discovery',
        facts: {
          'likedCount': liked.length,
          'sampleArtists': [
            for (final entry in rankedArtists.take(3)) entry.key,
          ],
          'sampleSongs': [
            for (final s in liked.take(3)) '${s.title} - ${s.artist}',
          ],
        },
      );
    }

    return null;
  }

  static (String, String, String)? _parseDropPayload(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fence != null) {
      text = fence.group(1)!.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) return null;
      final title = decoded['title']?.toString().trim() ?? '';
      final body = decoded['body']?.toString().trim() ?? '';
      final starterPrompt = decoded['starterPrompt']?.toString().trim() ?? '';
      if (title.isEmpty || body.isEmpty || starterPrompt.isEmpty) return null;
      return (title, body, starterPrompt);
    } catch (_) {
      return null;
    }
  }
}

class _DropSignal {
  const _DropSignal({
    required this.kind,
    required this.seedId,
    required this.facts,
  });

  final String kind;
  final String seedId;
  final Map<String, dynamic> facts;
}
