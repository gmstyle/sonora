import 'dart:async';

/// A readable projection of [PlaybackIntentController]'s state, for logging and
/// debugging. The three underlying flags stay authoritative.
enum PlaybackIntent {
  /// Nothing requested: no session, or the queue was replaced or cleared.
  idle,

  /// The user wants audio running.
  wantsPlaying,

  /// Paused from inside the app, so an unsolicited MediaSession PLAY is
  /// rejected until the app resumes deliberately.
  pausedByUser,

  /// Paused by something other than an in-app control — the media notification,
  /// a headset button, an audio-focus loss.
  pausedBySystem,
}

/// Single source of truth for *what the user wants* playback to be doing, as
/// opposed to what the engine is currently doing.
///
/// This used to be three booleans scattered across `SonoraAudioHandler`
/// (`_userWantsPlaying`, `_userExplicitlyPaused`, `_resumeAuthorized`), mutated
/// from about fifteen call sites and read by five controllers. The rules below
/// were only implicit in the conditionals; they are written out here so a change
/// can be checked against them.
///
/// ## Why the distinction exists
///
/// Pixel Buds ear-detection sends a MediaSession PLAY when the buds are put back
/// on. If the user had paused *from the app*, that PLAY must be ignored — but a
/// deliberate buds tap must still resume. So "paused" alone is not enough
/// information; the handler has to know *who* paused.
///
/// ## Truth table
///
/// | Event | `userWantsPlaying` | `isExplicitlyPaused` | Notes |
/// |---|---|---|---|
/// | [onPlayAccepted] — `play()` past the guard | `true` | `false` | In-app or accepted session play |
/// | [onFocusDenied] — audio focus refused | `false` | unchanged | Playback never started |
/// | [onUserPause] — `pauseFromUser()` | unchanged | `true` | Followed by [onPauseApplied] |
/// | [onPauseApplied] — `_pause()` reached the engine | `false` | unchanged | Shared by in-app and session pause |
/// | [onSessionPause] — notification / headset pause | unchanged | unchanged | Deliberately does *not* set explicit pause |
/// | [onStop] — `stop()` | `false` | `true` | Ends the session |
/// | [onQueueReplaced] — `setQueue()` | `false` | unchanged | Opens the playlist with `play: false` |
/// | [onNewSessionStarted] — `playNow()` entry | unchanged | `false` | Clears a pause left by `playAlbum` and friends |
/// | [onSessionOpened] — `playNow()` got focus | `hasFocus` | unchanged | |
/// | [onQueueCleared] — `clearQueue()` | `false` | unchanged | |
/// | [setUserWantsPlaying] — restore controller | as given | unchanged | Cold-start restore seeds the intent |
/// | [onEnginePlaying] `playing: true` | `true` | unchanged | Only after [shouldForcePause] declined |
/// | [onEnginePlaying] `playing: false` | `false` unless suppressed | unchanged | See below |
///
/// ## The two guards
///
/// [shouldRejectPlay] blocks `play()` when the app is explicitly paused, the
/// engine is *not* already playing, and no authorised resume is in flight. The
/// "engine not already playing" part matters: if audio is running, a `play()`
/// is treated as genuine and clears the explicit pause.
///
/// [shouldForcePause] pushes back on the engine when it starts playing while the
/// app is explicitly paused, which is how the spurious ear-detection PLAY is
/// undone.
///
/// Both are bypassed inside [runAuthorizedResume], the window `resumeFromUser()`
/// opens around a deliberate in-app resume.
///
/// ## Why `playing: false` can be suppressed
///
/// The engine reports "not playing" during a restore, while the volume
/// controller has muted a track transition, and while pausing to hand playback
/// to a cast device. None of those mean the user changed their mind, so
/// `suppressClear` keeps the intent intact across them.
class PlaybackIntentController {
  bool _userWantsPlaying = false;
  bool _explicitlyPaused = false;
  bool _resumeAuthorized = false;

  /// Whether the user currently wants audio running.
  bool get userWantsPlaying => _userWantsPlaying;

  /// Whether playback was paused from inside the app.
  bool get isExplicitlyPaused => _explicitlyPaused;

  /// True while [runAuthorizedResume] is in flight.
  bool get isResumeAuthorized => _resumeAuthorized;

  PlaybackIntent get intent {
    if (_userWantsPlaying) return PlaybackIntent.wantsPlaying;
    if (_explicitlyPaused) return PlaybackIntent.pausedByUser;
    return PlaybackIntent.idle;
  }

  // ── Guards ────────────────────────────────────────────────────────────────

  /// Whether `play()` should be ignored as an unsolicited MediaSession PLAY.
  bool shouldRejectPlay({required bool engineIsPlaying}) =>
      _explicitlyPaused && !engineIsPlaying && !_resumeAuthorized;

  /// Whether the engine reporting [playing] should be undone with a pause.
  bool shouldForcePause({required bool playing}) =>
      playing && _explicitlyPaused && !_resumeAuthorized;

  /// Runs [action] with both guards lifted, for a deliberate in-app resume.
  Future<T> runAuthorizedResume<T>(Future<T> Function() action) async {
    _resumeAuthorized = true;
    try {
      return await action();
    } finally {
      _resumeAuthorized = false;
    }
  }

  // ── Transport ─────────────────────────────────────────────────────────────

  /// `play()` passed [shouldRejectPlay] and is going ahead.
  void onPlayAccepted() {
    _explicitlyPaused = false;
    _userWantsPlaying = true;
  }

  /// The OS refused audio focus, so playback never started.
  void onFocusDenied() => _userWantsPlaying = false;

  /// In-app pause. Marks the pause as the user's, so ear-detection PLAY is
  /// rejected until the app resumes deliberately.
  void onUserPause() => _explicitlyPaused = true;

  /// Pause coming from the media notification, a headset button or Android
  /// Auto. Intentionally leaves [isExplicitlyPaused] alone so a following
  /// headset tap can resume.
  void onSessionPause() {}

  /// The pause reached the engine. Shared by the in-app and session paths.
  void onPauseApplied() => _userWantsPlaying = false;

  /// `stop()`: end the session and reject unsolicited PLAY afterwards.
  void onStop() {
    _explicitlyPaused = true;
    _userWantsPlaying = false;
  }

  /// `setQueue()` opens the new playlist paused.
  void onQueueReplaced() => _userWantsPlaying = false;

  /// `playNow()` is an explicit new session. `playAlbum` and friends call
  /// `pauseFromUser()` first, and leaving that pause set would make the engine
  /// immediately pause the freshly opened playlist.
  void onNewSessionStarted() => _explicitlyPaused = false;

  /// `playNow()` opened the playlist; playback started only if focus was granted.
  void onSessionOpened({required bool hasFocus}) =>
      _userWantsPlaying = hasFocus;

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
