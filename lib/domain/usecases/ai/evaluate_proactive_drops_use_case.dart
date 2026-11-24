import 'dart:convert';

import '../../models/ask_chat_models.dart';
import '../../repositories/ask_pulse_state_store.dart';
import '../../repositories/ask_storage_repository.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/llm_chat_repository.dart';
import '../../repositories/music_repository.dart';

const kPulseDropSystemInstruction = '''
You generate a short proactive music discovery card for a Sonora user.
Reply with ONLY a single JSON object:
{
  "title": "string (max 55 chars, catchy, warm & informal)",
  "body": "string (max 140 chars, casual music-friend tone using only the provided facts; informal 'tu' in Italian)",
  "starterPrompt": "string (max 120 chars, natural first-person prompt for Sonora Ask)"
}
Signal kinds you may receive:
- new_release: highlight the artist and new album/single release in the facts.
- new_podcast_episode: highlight the podcast name and new episode title in the facts.
- comeback_mix: warm welcome back mentioning daysAway and topArtists from the facts.
- weekly_recap: casual recap of the user's week using topArtists/sampleTracks.
- editorial_pulse: connect the editorial theme/hook with the user's topArtists.
- forgotten_favorites / heavy_rotation / taste_discovery: highlight the provided artists/tracks.
Rules:
- Mention ONLY artists, podcasts, releases, or songs present in the user facts.
- Never invent IDs, URLs, or facts.
- Never mention AI, models, or DeepSeek.
''';

/// Evaluates local listening patterns, optional catalog updates (new artist
/// releases / podcast episodes), and remote Cloudflare editorial sparks to
/// emit at most one personalized proactive discovery drop per cooldown window.
class EvaluateProactiveDropsUseCase {
  EvaluateProactiveDropsUseCase(
    this._library,
    this._storage,
    this._chatRepository, {
    this._musicRepository,
    this._stateStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LibraryRepository _library;
  final AskStorageRepository _storage;
  final LlmChatRepository _chatRepository;
  final MusicRepository? _musicRepository;
  final AskPulseStateStore? _stateStore;
  final DateTime Function() _now;

  static const Duration _defaultCooldown = Duration(hours: 48);
  static const int _artistBatchSize = 5;
  static const int _podcastBatchSize = 4;

  Future<AskProactiveDrop?> execute({
    required String locale,
    AskPulseRemoteConfig? remoteConfig,
    bool allowCatalogChecks = true,
  }) async {
    if (remoteConfig != null &&
        (!remoteConfig.enabled || remoteConfig.weeklyRemaining <= 0)) {
      return null;
    }

    final now = _now();
    final cooldown = remoteConfig != null
        ? Duration(hours: remoteConfig.cooldownHours)
        : _defaultCooldown;

    final recent = await _storage.getRecentDrops(limit: 100);
    if (recent.any((d) => now.difference(d.createdAt) < cooldown)) {
      return null;
    }
    if (!await _chatRepository.isReady()) return null;

    final usedSeeds = recent
        .map((d) => d.seedId)
        .whereType<String>()
        .map((s) => s.toLowerCase())
        .toSet();

    final signal = await _detectSignal(
      now: now,
      usedSeeds: usedSeeds,
      remoteConfig: remoteConfig,
      allowCatalogChecks: allowCatalogChecks,
    );
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

  bool _isEnabled(AskPulseRemoteConfig? config, String kind) =>
      config == null || config.isTriggerEnabled(kind);

  Future<_DropSignal?> _detectSignal({
    required DateTime now,
    required Set<String> usedSeeds,
    required AskPulseRemoteConfig? remoteConfig,
    required bool allowCatalogChecks,
  }) async {
    if (allowCatalogChecks &&
        _musicRepository != null &&
        _stateStore != null &&
        _isEnabled(remoteConfig, 'new_release')) {
      final releaseSignal = await _detectNewArtistRelease(now, usedSeeds);
      if (releaseSignal != null) return releaseSignal;
    }

    if (allowCatalogChecks &&
        _musicRepository != null &&
        _stateStore != null &&
        _isEnabled(remoteConfig, 'new_podcast_episode')) {
      final episodeSignal = await _detectNewPodcastEpisode(usedSeeds);
      if (episodeSignal != null) return episodeSignal;
    }

    final history = await _library.getRecentHistory(limit: 40);
    final artistCounts = <String, int>{};
    for (final h in history) {
      final artist = h.artist.trim();
      if (artist.isEmpty) continue;
      artistCounts[artist] = (artistCounts[artist] ?? 0) + h.playCount;
    }
    final rankedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (_isEnabled(remoteConfig, 'comeback_mix') && history.isNotEmpty) {
      var latestPlayed = history.first.playedAt;
      for (final h in history.skip(1)) {
        if (h.playedAt.isAfter(latestPlayed)) {
          latestPlayed = h.playedAt;
        }
      }
      final away = now.difference(latestPlayed);
      final seed = 'comeback:${latestPlayed.millisecondsSinceEpoch}';
      if (away >= const Duration(days: 5) && !usedSeeds.contains(seed)) {
        return _DropSignal(
          kind: 'comeback_mix',
          seedId: seed,
          facts: {
            'daysAway': away.inDays,
            'topArtists': [
              for (final entry in rankedArtists.take(3)) entry.key,
            ],
            'recentTracks': [
              for (final h in history.take(3)) '${h.title} - ${h.artist}',
            ],
          },
        );
      }
    }

    if (_isEnabled(remoteConfig, 'weekly_recap') &&
        ((now.weekday == DateTime.friday && now.hour >= 15) ||
            (now.weekday == DateTime.sunday && now.hour >= 16))) {
      final weekCutoff = now.subtract(const Duration(days: 7));
      final weeklyTracks = history
          .where((h) => !h.playedAt.isBefore(weekCutoff))
          .toList(growable: false);
      final weeklyPlays = weeklyTracks.fold<int>(
        0,
        (sum, item) => sum + item.playCount,
      );
      final weekKey = _isoWeekKey(now);
      final seed = 'weekly_recap:${weekKey.toLowerCase()}';
      if (weeklyPlays >= 5 && !usedSeeds.contains(seed)) {
        final weeklyArtistCounts = <String, int>{};
        for (final h in weeklyTracks) {
          final artist = h.artist.trim();
          if (artist.isEmpty) continue;
          weeklyArtistCounts[artist] =
              (weeklyArtistCounts[artist] ?? 0) + h.playCount;
        }
        final topWeeklyArtists = weeklyArtistCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return _DropSignal(
          kind: 'weekly_recap',
          seedId: seed,
          facts: {
            'week': weekKey,
            'weeklyPlays': weeklyPlays,
            'topArtists': [
              for (final entry in topWeeklyArtists.take(3)) entry.key,
            ],
            'sampleTracks': [
              for (final h in weeklyTracks.take(3)) '${h.title} - ${h.artist}',
            ],
          },
        );
      }
    }

    final liked = await _library.getAllLikedSongs();

    final editorial = remoteConfig?.editorialPulse;
    if (_isEnabled(remoteConfig, 'editorial_pulse') && editorial != null) {
      final seed = 'editorial:${editorial.id.toLowerCase()}';
      if (!usedSeeds.contains(seed) && liked.length + history.length >= 3) {
        return _DropSignal(
          kind: 'editorial_pulse',
          seedId: seed,
          facts: {
            'theme': editorial.theme,
            'hook': editorial.hook,
            'moodKeywords': editorial.moodKeywords,
            'promptAngle': editorial.promptAngle,
            'topArtists': [
              for (final entry in rankedArtists.take(3)) entry.key,
            ],
          },
        );
      }
    }

    if (_isEnabled(remoteConfig, 'forgotten_favorites')) {
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
    }

    if (_isEnabled(remoteConfig, 'heavy_rotation')) {
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
    }

    if (_isEnabled(remoteConfig, 'taste_discovery') &&
        liked.length + history.length >= 5 &&
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

  Future<_DropSignal?> _detectNewArtistRelease(
    DateTime now,
    Set<String> usedSeeds,
  ) async {
    final followed = await _library.getAllFollowedArtists();
    final albums = await _library.getAllLikedAlbums();
    final liked = await _library.getAllLikedSongs();

    final candidates = <({String id, String name})>[];
    final seenIds = <String>{};
    void addCandidate(String? id, String name) {
      final cleanId = id?.trim() ?? '';
      final cleanName = name.trim();
      if (cleanId.isEmpty || cleanName.isEmpty) return;
      if (seenIds.add(cleanId)) {
        candidates.add((id: cleanId, name: cleanName));
      }
    }

    for (final artist in followed) {
      addCandidate(artist.artistId, artist.name);
    }
    for (final album in albums) {
      addCandidate(album.artistId, album.artistName);
    }
    for (final song in liked) {
      addCandidate(song.artistId, song.artist);
    }
    if (candidates.isEmpty) return null;

    final cursor = await _stateStore!.getArtistCursor();
    final start = cursor % candidates.length;
    final batchCount = candidates.length < _artistBatchSize
        ? candidates.length
        : _artistBatchSize;
    final batch = [
      for (var i = 0; i < batchCount; i++)
        candidates[(start + i) % candidates.length],
    ];
    await _stateStore.setArtistCursor((start + batchCount) % candidates.length);

    final seenMap = await _stateStore.getSeenReleasesByArtist();
    var seenDirty = false;
    _DropSignal? matchedSignal;

    for (final candidate in batch) {
      try {
        final full = await _musicRepository!.getArtist(candidate.id);
        final releases = [
          ...full.topAlbums,
          ...full.topSingles,
        ].where((r) => r.albumId.trim().isNotEmpty).toList(growable: false);
        if (releases.isEmpty) continue;

        final currentIds = releases
            .map((r) => r.albumId.trim())
            .toList(growable: false);
        final previous = seenMap[candidate.id];

        if (previous == null) {
          seenMap[candidate.id] = currentIds;
          seenDirty = true;
          continue;
        }

        final previousSet = previous.toSet();
        for (final release in releases) {
          final albumId = release.albumId.trim();
          if (previousSet.contains(albumId)) continue;
          final yearOk = release.year == null || release.year! >= now.year - 1;
          final seed = 'release:${albumId.toLowerCase()}';
          if (yearOk && !usedSeeds.contains(seed)) {
            matchedSignal = _DropSignal(
              kind: 'new_release',
              seedId: seed,
              facts: {
                'artist': candidate.name,
                'releaseTitle': release.name,
                'releaseType': release.type,
                if (release.year != null) 'year': release.year,
              },
            );
            break;
          }
        }

        final mergedIds = [
          ...currentIds,
          for (final oldId in previous)
            if (!currentIds.contains(oldId)) oldId,
        ];
        seenMap[candidate.id] = mergedIds;
        seenDirty = true;
        if (matchedSignal != null) break;
      } catch (_) {
        // Skip transient per-artist catalog error without poisoning the batch.
      }
    }

    if (seenDirty) {
      await _stateStore.saveSeenReleasesByArtist(seenMap);
    }
    return matchedSignal;
  }

  Future<_DropSignal?> _detectNewPodcastEpisode(Set<String> usedSeeds) async {
    final podcasts = await _library.getAllLikedPodcasts();
    if (podcasts.isEmpty) return null;

    final cursor = await _stateStore!.getPodcastCursor();
    final start = cursor % podcasts.length;
    final batchCount = podcasts.length < _podcastBatchSize
        ? podcasts.length
        : _podcastBatchSize;
    final batch = [
      for (var i = 0; i < batchCount; i++)
        podcasts[(start + i) % podcasts.length],
    ];
    await _stateStore.setPodcastCursor((start + batchCount) % podcasts.length);

    final seenMap = await _stateStore.getSeenEpisodesByPodcast();
    var seenDirty = false;
    _DropSignal? matchedSignal;

    for (final podcast in batch) {
      final browseId = podcast.browseId.trim();
      if (browseId.isEmpty) continue;
      try {
        final full = await _musicRepository!.getPodcast(browseId, limit: 5);
        final episodeIds = full.episodes
            .map((e) => e.videoId.trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        if (episodeIds.isEmpty) continue;

        final previous = seenMap[browseId];
        if (previous == null) {
          seenMap[browseId] = episodeIds;
          seenDirty = true;
          continue;
        }

        final previousSet = previous.toSet();
        for (final ep in full.episodes) {
          final epId = ep.videoId.trim();
          if (epId.isEmpty || previousSet.contains(epId)) continue;
          final seed = 'episode:${epId.toLowerCase()}';
          if (!usedSeeds.contains(seed)) {
            matchedSignal = _DropSignal(
              kind: 'new_podcast_episode',
              seedId: seed,
              facts: {
                'podcast': podcast.name,
                'episodeTitle': ep.name,
                if (ep.date != null && ep.date!.isNotEmpty) 'date': ep.date,
              },
            );
            break;
          }
        }

        final mergedIds = [
          ...episodeIds,
          for (final oldId in previous)
            if (!episodeIds.contains(oldId)) oldId,
        ];
        seenMap[browseId] = mergedIds;
        seenDirty = true;
        if (matchedSignal != null) break;
      } catch (_) {
        // Ignore single-podcast fetch error and try the next item in the batch.
      }
    }

    if (seenDirty) {
      await _stateStore.saveSeenEpisodesByPodcast(seenMap);
    }
    return matchedSignal;
  }

  static String _isoWeekKey(DateTime now) {
    final utcDate = DateTime.utc(now.year, now.month, now.day);
    final dayNum = utcDate.weekday;
    final thursday = utcDate.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
    return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
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
