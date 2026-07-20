import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/youtube_request_scheduler.dart';

/// Covers the anti-429 concurrency gate: at most [maxConcurrent] actions run
/// at the same time, and consecutive actions cannot start closer together
/// than [minSpacing] — the preventive layer added in front of every YouTube
/// manifest request (see [YoutubeRequestScheduler] doc comment for why).
void main() {
  test('limits the number of concurrently running actions', () async {
    final scheduler = YoutubeRequestScheduler(
      maxConcurrent: 2,
      minSpacing: Duration.zero,
    );

    int inFlight = 0;
    int maxObservedInFlight = 0;
    final completers = List.generate(5, (_) => Completer<void>());

    final futures = [
      for (var i = 0; i < 5; i++)
        scheduler.schedule(() async {
          inFlight++;
          maxObservedInFlight =
              inFlight > maxObservedInFlight ? inFlight : maxObservedInFlight;
          await completers[i].future;
          inFlight--;
          return i;
        }),
    ];

    // Let the first batch actually start.
    await Future<void>.delayed(Duration.zero);
    expect(maxObservedInFlight, 2);

    // Release them one at a time and make sure concurrency never exceeds 2.
    for (final c in completers) {
      c.complete();
      await Future<void>.delayed(Duration.zero);
      expect(maxObservedInFlight, lessThanOrEqualTo(2));
    }

    final results = await Future.wait(futures);
    expect(results.toSet(), {0, 1, 2, 3, 4});
  });

  test('enforces a minimum spacing between the start of each action', () async {
    final scheduler = YoutubeRequestScheduler(
      maxConcurrent: 5, // effectively unlimited concurrency for this test
      minSpacing: const Duration(milliseconds: 50),
    );

    final starts = <DateTime>[];
    await Future.wait([
      for (var i = 0; i < 3; i++)
        scheduler.schedule(() async {
          starts.add(DateTime.now());
        }),
    ]);

    starts.sort();
    for (var i = 1; i < starts.length; i++) {
      final gap = starts[i].difference(starts[i - 1]);
      expect(
        gap.inMilliseconds,
        greaterThanOrEqualTo(45), // small tolerance for timer jitter
      );
    }
  });

  test('releases the slot even when the action throws', () async {
    final scheduler = YoutubeRequestScheduler(
      maxConcurrent: 1,
      minSpacing: Duration.zero,
    );

    await expectLater(
      scheduler.schedule(() async => throw StateError('boom')),
      throwsStateError,
    );

    // If the slot wasn't released, this would hang forever.
    final result = await scheduler
        .schedule(() async => 'ok')
        .timeout(const Duration(seconds: 2));
    expect(result, 'ok');
  });
}
