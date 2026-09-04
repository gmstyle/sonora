# just_audio migration plan

Working plan for the `media_kit` → `just_audio` + `audio_service` refactor.
Target branch: `dev-just-audio`. After the migration lands, fold the new
architecture into [SONORA-DEV-DOCS.md](SONORA-DEV-DOCS.md) and delete this file.

Status: **decisions locked**, implementation not started.

## Locked decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Linux equalizer | Fork / patch `just_audio_media_kit` to expose mpv `af` (keep the current 5-band lavfi graph). Android uses `AndroidEqualizer` with interpolation onto device bands. Same UI and presets. |
| 2 | Downloads | Audio-only. Never muxed / video. Use existing `Settings.downloadQuality` (`high` / `mid` / `low`) via `StreamQualitySelector` with `preferVideo: false`. |
| 3 | Stream cache | Keep `LocalAudioProxyServer` + `MediaCacheService` LRU. Do **not** use `LockCachingAudioSource`. Strip muxed / `{id}.v.*` / adaptive-pair paths. |
| 4 | Linux gapless | **Deferred — next step after the first cut.** See [Follow-up: Linux gapless](#follow-up-linux-gapless). |
| 5 | Video catalog | Keep `isVideo`, artist/user Videos screens, `contentType: video`. They play as audio. Remove playback UI, `enableVideoPlayback`, textures. |

Also locked:

- Keep `audio_service` (notifications, Android Auto, Bluetooth / earbuds, MPRIS).
- Keep Dart-side `SkipNavigator` (do not enable just_audio shuffle: `just_audio_media_kit` ignores `shuffleOrder`).
- `AudioPlayer(handleInterruptions: false, useProxyForRequestHeaders: false)` so Sonora’s `AudioSessionController` and loopback proxy stay in charge.
- Introduce a thin `PlaybackEngine` adapter; do not find-replace `media_kit.Player` across 15 controllers.

## Target stack

| Platform | Engine | Session |
|---|---|---|
| Android | `just_audio` (ExoPlayer) | `audio_service` |
| Linux | `just_audio` + forked `just_audio_media_kit` (libmpv audio-only) | `audio_service` + `audio_service_mpris` |

Drop: `media_kit_video`, `media_kit_libs_android_video`, `VideoPlayerNotifier`, `SonoraVideoPlayer`, `ExternalAudioTrackController`.

Linux still needs system `libmpv` (DEB/RPM unchanged). Android loses bundled `libmpv.so`.

## Implementation phases (first cut)

0. **Spike** — one YouTube audio URL through the existing proxy on Android and Linux; Range seek; local `file://`; validate Linux `af` via the fork.
1. **`PlaybackEngine` + `PlaybackStatePublisher`** — map `ProcessingState` → `AudioProcessingState`; keep the “empty playlist during restore/resolve ⇒ buffering not idle” rule (Android Auto MediaSession).
2. **Queue / open / restore / recovery** — `setAudioSources`, insert/remove/move, URL replace, `TrackUrlResolver`, `PlayVideoIdUseCase` audio-only.
3. **Cache + streams** — audio-only disk layout, drop `preferVideo` / `v=1`, quality-change cache clear.
4. **EQ + volume + Linux engine config** — dual EQ backends; `JustAudioMediaKit.bufferSize` / `title` / protocol whitelist (`file`, `http`, `https`).
5. **Remove video UI + setting** — artwork only; ignore `enableVideoPlayback` on backup import.
6. **Integration + docs** — Android + Linux matrix (queue, AA, cast, earbuds, EQ, cache, downloads). Update SONORA-DEV-DOCS / README / apk-size-baseline.

Do not enable `JustAudioMediaKit.prefetchPlaylist` in phases 0–6.

## Follow-up: Linux gapless

**When:** immediately after the first cut is stable (queue, restore, cache, EQ).
**What:** evaluate `JustAudioMediaKit.prefetchPlaylist = true` (mpv `--prefetch-playlist`).

Android already gets native gapless from ExoPlayer playlists. Linux does not, unless this flag is on. It is marked experimental by the plugin.

Sonora’s crossfade (`Settings.crossfadeSeconds`, default 2s) is a volume envelope on **one** player. It can hide a short gap; it is not overlapping two decoders. With crossfade set to 0, a Linux micro-pause between tracks may be audible.

Risks to re-test if the flag is enabled:

- `TrackUrlResolver` replacing the next item’s URI while mpv is already prefetching it
- `needsUrl` placeholders being prefetched before resolve
- Shuffle: mpv prefetches playlist `index+1`, not `SkipNavigator`’s random next

Acceptance: A/B on Linux (`false` vs `true`) through sequential play, shuffle, rapid skip, URL expiry / 403 refresh, and crossfade 0 / 2 / N seconds. Turn it on only if transitions improve without breaking those paths.

## Feature parity (first cut)

Must keep: queue user/up-next, skip/shuffle/repeat, restore, recovery + proxy 403/429, stream cache LRU, downloads (audio + `downloadQuality`), Android Auto, Chromecast/DLNA, Bluetooth commands + `PlaybackIntentController`, 5-band EQ, crossfade, MPRIS/tray.

Must drop: video decode, muxed downloads, `enableVideoPlayback`.
