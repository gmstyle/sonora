import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/models/music_search_intent.dart';
import 'package:sonora/domain/usecases/ai/moment_mix_assembler.dart';

void main() {
  const assembler = MomentMixAssembler(cap: 10);
  final now = DateTime(2026, 10, 17, 12);

  HistoryModel history({
    required String id,
    required String title,
    required String artist,
    int playCount = 1,
    DateTime? playedAt,
    String contentType = 'song',
  }) {
    return HistoryModel(
      id: id.hashCode,
      videoId: id,
      title: title,
      artist: artist,
      playedAt: playedAt ?? now.subtract(const Duration(days: 1)),
      playCount: playCount,
      contentType: contentType,
    );
  }

  LikedSongModel liked({
    required String id,
    required String title,
    required String artist,
    DateTime? addedAt,
  }) {
    return LikedSongModel(
      videoId: id,
      title: title,
      artist: artist,
      addedAt: addedAt ?? now.subtract(const Duration(days: 60)),
    );
  }

  test('ranks seed-artist matches first and caps the queue', () {
    final intent = MusicSearchIntent(
      searchQuery: 'rock focus',
      mood: 'focus',
      energy: MixEnergy.medium,
      seedArtists: const ['Ligabue'],
      source: MixSource.history,
    );

    final tracks = assembler.selectLocalTracks(
      intent: intent,
      now: now,
      history: [
        history(id: 'a', title: 'Other', artist: 'Someone', playCount: 99),
        history(id: 'b', title: 'Certe Notti', artist: 'Ligabue', playCount: 2),
        history(id: 'c', title: 'Balliamo', artist: 'Ligabue', playCount: 5),
        for (var i = 0; i < 20; i++)
          history(id: 'f$i', title: 'Filler $i', artist: 'Band $i'),
      ],
      liked: const [],
    );

    expect(tracks.length, lessThanOrEqualTo(10));
    expect(tracks.first.videoId, anyOf('b', 'c'));
    expect(tracks.take(2).map((t) => t.artist), everyElement('Ligabue'));
  });

  test('skips podcast episodes from history', () {
    final intent = const MusicSearchIntent(
      searchQuery: 'talk',
      source: MixSource.history,
    );
    final tracks = assembler.selectLocalTracks(
      intent: intent,
      now: now,
      history: [
        history(
          id: 'ep1',
          title: 'Episode 1',
          artist: 'Host',
          contentType: 'episode',
        ),
        history(id: 's1', title: 'Song', artist: 'Artist'),
      ],
      liked: const [],
    );
    expect(tracks.map((t) => t.videoId), ['s1']);
  });

  test('mergeDedupe prefers history then fills from ytm', () {
    final historyTracks = [
      history(id: 'h1', title: 'H1', artist: 'A'),
      history(id: 'shared', title: 'Shared', artist: 'A'),
    ];
    final ytm = [
      liked(id: 'shared', title: 'Shared YTM', artist: 'A'),
      liked(id: 'y1', title: 'Y1', artist: 'B'),
      liked(id: 'y2', title: 'Y2', artist: 'C'),
    ];

    final merged = assembler.mergeDedupe(historyFirst: historyTracks, ytm: ytm);
    expect(merged.map((t) => t.videoId), ['h1', 'shared', 'y1', 'y2']);
    expect(merged[1], isA<HistoryModel>());
  });

  test('low energy boosts older plays', () {
    final intent = const MusicSearchIntent(
      searchQuery: 'calm evening',
      mood: 'calm',
      energy: MixEnergy.low,
      source: MixSource.history,
    );
    final tracks = assembler.selectLocalTracks(
      intent: intent,
      now: now,
      history: [
        history(
          id: 'recent',
          title: 'Fresh Hit',
          artist: 'Pop',
          playCount: 50,
          playedAt: now.subtract(const Duration(hours: 2)),
        ),
        history(
          id: 'old',
          title: 'Calm Evening Song',
          artist: 'Soft',
          playCount: 3,
          playedAt: now.subtract(const Duration(days: 45)),
        ),
      ],
      liked: const [],
    );
    expect(tracks.first.videoId, 'old');
  });
}
