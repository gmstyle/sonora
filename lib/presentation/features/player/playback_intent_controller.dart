/// A readable projection of [PlaybackIntentController]'s state, for logging and
/// debugging. [userWantsPlaying] stays authoritative.
enum PlaybackIntent {
  /// Nothing requested: paused, stopped, or the queue was replaced or cleared.
  idle,

  /// The user wants audio running.
  wantsPlaying,
}

/// Single source of truth for *what the user wants* playback to be doing, as
/// opposed to what the engine is currently doing.
///
/// In-app controls and MediaSession (notification, Android Auto, headset) share
/// the same `play()` / `pause()` / `stop()` contract. PLAY is never rejected.
/// Local audio focus, interruptions and becoming-noisy belong to `just_audio`.
///
/// ## Truth table
///
/// | Event | `userWantsPlaying` | Notes |
/// |---|---|---|
/// | [onPlayAccepted] — `play()` / `playNow()` | `true` | In-app or MediaSession play |
/// | [onPauseApplied] — `_pause()` reached the engine | `false` | In-app or MediaSession pause |
/// | [onStop] — `stop()` | `false` | Ends the session |
/// | [onQueueReplaced] — `setQueue()` | `false` | Opens the playlist with `play: false` |
/// | [onQueueCleared] — `clearQueue()` | `false` | |
/// | [setUserWantsPlaying] — restore controller | as given | Cold-start restore seeds the intent |
/// | [onEnginePlaying] `playing: true` | `true` | Engine is audible |
/// | [onEnginePlaying] `playing: false` | `false` unless suppressed | See below |
///
/// ## Why `playing: false` can be suppressed
///
/// The engine reports "not playing" during a restore, while the volume
/// controller has muted a track transition, and while pausing to hand playback
/// to a cast device. None of those mean the user changed their mind, so
/// `suppressClear` keeps the intent intact across them.
class PlaybackIntentController {
  bool _userWantsPlaying = false;

  /// Whether the user currently wants audio running.
  bool get userWantsPlaying => _userWantsPlaying;

  PlaybackIntent get intent =>
      _userWantsPlaying ? PlaybackIntent.wantsPlaying : PlaybackIntent.idle;

  // ── Transport ─────────────────────────────────────────────────────────────

  /// `play()` / `playNow()` is going ahead (in-app, notification, Android Auto,
  /// or headset).
  void onPlayAccepted() => _userWantsPlaying = true;

  /// The pause reached the engine. Shared by the in-app and session paths.
  void onPauseApplied() => _userWantsPlaying = false;

  /// `stop()`: end the session.
  void onStop() => _userWantsPlaying = false;

  /// `setQueue()` opens the new playlist paused.
  void onQueueReplaced() => _userWantsPlaying = false;

  void onQueueCleared() => _userWantsPlaying = false;

  /// Used by the restore controller to seed the intent on cold start.
  void setUserWantsPlaying(bool value) => _userWantsPlaying = value;

  // ── Engine feedback ───────────────────────────────────────────────────────

  /// Folds an engine playing/paused report into the intent.
  ///
  /// [suppressClear] must be true while restoring, while a track transition is
  /// muted, and while pausing for a cast handover: the engine is not playing,
  /// but the user has not changed their mind.
  void onEnginePlaying(bool playing, {required bool suppressClear}) {
    if (playing) {
      _userWantsPlaying = true;
    } else if (!suppressClear) {
      _userWantsPlaying = false;
    }
  }
}
