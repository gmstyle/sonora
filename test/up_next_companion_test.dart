import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/widgets/up_next_companion.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

void main() {
  MediaItem track(String id) => MediaItem(id: id, title: id);

  test('upcoming tracks follow the queue after the current index', () {
    final state = PlayerState(
      queue: [track('a'), track('b'), track('c'), track('d')],
      currentIndex: 1,
      upNextQueue: [track('d')],
    );

    final rows = upcomingTracks(state, limit: 2);

    expect(rows.map((row) => row.item.id), ['c', 'd']);
    expect(rows.first.queueIndex, 2);
    expect(rows.last.queueIndex, 3);
  });

  test('falls back to the radio section when the queue has no follower', () {
    final state = PlayerState(
      queue: [track('a')],
      currentIndex: 0,
      upNextQueue: [track('radio')],
    );

    final rows = upcomingTracks(state);

    expect(rows, hasLength(1));
    expect(rows.single.item.id, 'radio');
    expect(rows.single.queueIndex, isNull);
  });

  test('limit zero yields nothing', () {
    final state = PlayerState(queue: [track('a'), track('b')], currentIndex: 0);

    expect(upcomingTracks(state, limit: 0), isEmpty);
  });
}
