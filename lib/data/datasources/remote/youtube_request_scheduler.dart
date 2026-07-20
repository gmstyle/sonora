import 'dart:async';
import 'dart:collection';

/// Global gate for every outbound request this app makes to YouTube
/// (stream URL / manifest resolution for playback and downloads).
///
/// # Why this exists
///
/// Before this scheduler, the only anti-429 protection was a per-call retry
/// with exponential back-off inside [StreamDatasource.getStreamUrl] — a
/// purely *reactive* measure. Nothing stopped the app from firing several
/// concurrent manifest requests in the first place (e.g. resolving the
/// current + next + look-ahead queue items right after the app resumes from
/// a long background period, when several stream URLs have expired at
/// once). That kind of burst is exactly what triggers YouTube's rate
/// limiter to begin with.
///
/// This scheduler adds a *preventive* layer in front of every request:
///
///  - **Bounded concurrency**: at most [maxConcurrent] manifest fetches are
///    ever in flight at the same time; extra callers simply queue up (FIFO)
///    instead of firing immediately.
///  - **Minimum spacing**: even when a concurrency slot is free, a new
///    request will not *start* less than [minSpacing] after the previous
///    one started, smoothing out bursts instead of firing several requests
///    in the same instant.
///
/// A single, process-wide instance ([shared]) is used by both playback URL
/// resolution and downloads, since they all draw from the same YouTube-side
/// rate-limit budget.
class YoutubeRequestScheduler {
  YoutubeRequestScheduler({
    this.maxConcurrent = 2,
    this.minSpacing = const Duration(milliseconds: 400),
  });

  /// Shared instance used across the app. Tests may construct their own
  /// [YoutubeRequestScheduler] instance instead (e.g. with a shorter
  /// [minSpacing]) and inject it where needed.
  static final YoutubeRequestScheduler shared = YoutubeRequestScheduler();

  final int maxConcurrent;
  final Duration minSpacing;

  int _active = 0;

  /// The earliest time the *next* request is allowed to start. Reserved
  /// synchronously (see [_acquire]) so that several callers arriving in the
  /// same event-loop turn each claim a distinct, monotonically increasing
  /// slot instead of all computing their wait relative to the same stale
  /// "last start" timestamp and waking up simultaneously.
  DateTime? _nextAllowedStart;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// Runs [action] once a concurrency slot is available and the minimum
  /// spacing since the last request start has elapsed. Requests are
  /// released as soon as [action] completes (successfully or not), so a
  /// failing request never holds up the queue.
  Future<T> schedule<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    while (_active >= maxConcurrent) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _active++;

    final now = DateTime.now();
    final earliestStart = _nextAllowedStart;
    final scheduledStart =
        (earliestStart != null && earliestStart.isAfter(now))
            ? earliestStart
            : now;
    // Reserve the following slot immediately (synchronously, before any
    // `await` below) so the next caller — even one arriving in the same
    // synchronous burst — sees an up-to-date cursor.
    _nextAllowedStart = scheduledStart.add(minSpacing);

    final delay = scheduledStart.difference(now);
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
  }

  void _release() {
    _active--;
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }
}
