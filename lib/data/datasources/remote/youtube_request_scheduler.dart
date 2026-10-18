import 'dart:async';
import 'dart:collection';

import '../../../core/errors/youtube_rate_limited_exception.dart';

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
///  - **Cool-down circuit**: after a YouTube HTTP 429, [enterCoolDown] blocks
///    further scheduled work for [coolDown] so retries and prefetch cannot
///    extend the IP-level block.
///
/// A single, process-wide instance ([shared]) is used by both playback URL
/// resolution and downloads, since they all draw from the same YouTube-side
/// rate-limit budget.
class YoutubeRequestScheduler {
  YoutubeRequestScheduler({
    this.maxConcurrent = 2,
    this.minSpacing = const Duration(milliseconds: 600),
    this.coolDown = const Duration(minutes: 15),
  });

  /// Shared instance used across the app. Tests may construct their own
  /// [YoutubeRequestScheduler] instance instead (e.g. with a shorter
  /// [minSpacing]) and inject it where needed.
  static final YoutubeRequestScheduler shared = YoutubeRequestScheduler();

  final int maxConcurrent;
  final Duration minSpacing;

  /// How long to refuse new work after [enterCoolDown].
  final Duration coolDown;

  int _active = 0;

  /// The earliest time the *next* request is allowed to start. Reserved
  /// synchronously (see [_acquire]) so that several callers arriving in the
  /// same event-loop turn each claim a distinct, monotonically increasing
  /// slot instead of all computing their wait relative to the same stale
  /// "last start" timestamp and waking up simultaneously.
  DateTime? _nextAllowedStart;
  DateTime? _coolDownUntil;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// True while a cool-down started by [enterCoolDown] is still active.
  bool get isCoolingDown {
    final until = _coolDownUntil;
    if (until == null) return false;
    if (!DateTime.now().isBefore(until)) {
      _coolDownUntil = null;
      return false;
    }
    return true;
  }

  /// Remaining cool-down, or `null` when not cooling down.
  Duration? get coolDownRemaining {
    if (!isCoolingDown) return null;
    return _coolDownUntil!.difference(DateTime.now());
  }

  /// Opens the cool-down circuit. Further [schedule] calls fail fast with
  /// [YoutubeRateLimitedException] until [coolDown] elapses (or a longer
  /// remaining cool-down already in effect ends).
  void enterCoolDown([Duration? duration]) {
    final until = DateTime.now().add(duration ?? coolDown);
    if (_coolDownUntil == null || until.isAfter(_coolDownUntil!)) {
      _coolDownUntil = until;
    }
  }

  /// Clears any active cool-down (tests / manual recovery).
  void clearCoolDown() {
    _coolDownUntil = null;
  }

  /// Runs [action] once a concurrency slot is available and the minimum
  /// spacing since the last request start has elapsed. Requests are
  /// released as soon as [action] completes (successfully or not), so a
  /// failing request never holds up the queue.
  ///
  /// Throws [YoutubeRateLimitedException] immediately when cooling down.
  Future<T> schedule<T>(Future<T> Function() action) async {
    _throwIfCoolingDown();
    await _acquire();
    try {
      _throwIfCoolingDown();
      return await action();
    } finally {
      _release();
    }
  }

  void _throwIfCoolingDown() {
    final remaining = coolDownRemaining;
    if (remaining != null) {
      throw YoutubeRateLimitedException(remaining);
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
