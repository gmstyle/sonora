# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/).

## [1.8.7+68] - 2026-09-22

### Bug Fixes

- **downloads**: Capture context-menu song download before sheet close
- **downloads**: Keep context-menu collection downloads after sheet close

## [1.8.6+67] - 2026-09-20

### Features

- **library**: Confirm before linked playlist sync
- **ui**: Unify detail affinity icons and download states
- **ui**: Share detail action bar with cap/overflow and hide self-nav
- **library**: Add linked playlist pull-sync with Spotify 12h gate
- **downloads**: Organize completed downloads by collection
- **downloads**: Improve download UX with batch cancel and grouped progress

### Bug Fixes

- **player**: Soft offline transition and single resolveUrl path
- **player**: Honor Settings offline mode for streams and cache
- **cli**: Play completed downloads without Innertube init
- **downloads**: Keep completed files until a re-download succeeds
- **player**: Separate mini seek strip from play controls
- **ui**: Fix detail action bar alignment and More duplicates
- **ui**: Use adaptive ContextMenuSheet for local playlist More
- **player**: Play downloaded tracks from local files on all play paths

## [1.8.5+66] - 2026-09-17

### Bug Fixes

- **library**: Show Go to Artist on imported playlist tracks

## [1.8.4+65] - 2026-09-17

### Features

- **library**: Stabilize import playlist overlay across breakpoints
- **library**: Persist multi-artist credits on imported playlists
- Multi-artist credits from dart_ytmusic_api 1.8.0
- **library**: Import public Spotify playlists

### Bug Fixes

- **library**: Keep the import playlist sheet usable above the keyboard

## [1.8.3+64] - 2026-09-13

### Features

- **player**: Podcast-aware full player UX and landscape fixes
- **ux**: Polish Settings rail, Clear Queue, Cast, shimmer, offline CTA
- **ux**: Pin Explore, trim tablet framing, move Settings off nav
- **ui**: Tighten library, search, and nav chrome

### Bug Fixes

- **player**: Advance Cast queue when a remote track ends
- **player**: Refresh warm stream URL on MediaSession play
- **player**: Follow the standard MediaSession play/pause contract

## [1.8.2+63] - 2026-09-12

### Features

- **player**: Show album, artist, or podcast context in the sidebar now-playing card
- **player**: Replace capsule seek bar with a thin streaming track

### Bug Fixes

- **player**: Let just_audio own local audio session handling
- **player**: Open full player from any mobile mini-player tap

## [1.8.1+62] - 2026-09-05

### Features

- **player**: Split now-playing chrome from mini-player transport

### Bug Fixes

- **player**: Keep restored queue index from jumping back on startup

## [1.8.0+61] - 2026-09-05

### Features

- **player**: Switch playback engine to just_audio

### Bug Fixes

- **settings**: Align backup keys and migrate leftover prefs
- **player**: Cache lookahead with authenticated downloads
- **linux**: Ship window icon and silence ayatana deprecation
- **update**: Ship universal APK with ABI splits for updater bridge
- **player**: Allow Pixel Buds tap after in-app pause
- **player**: Hand off playback to Chromecast without dual audio
- **player**: Do not wipe queue pointer during cold restore
- **android**: Allow loopback HTTP for the local audio proxy
- **player**: Restore queue paused without hanging mini-player
- **player**: Shuffle on track end and unstick mini-player loading
- **download**: Fetch song bytes through youtube_explode, not a raw Dio GET
- **home**: Render song shelves instead of empty hero carousel
- **update**: Pick the APK matching the device ABI
- **player**: Allow earbuds tap-to-resume after MediaSession pause

## [1.7.4+60] - 2026-09-02

### Bug Fixes

- **ui**: Stop shimmer carousel cards overflowing by 10px
- **player**: Allow playNow after pause so artist/album play starts
- **player**: Block spurious resume when earbuds removed while paused
- **linux**: Skip Android Auto notifyChildrenChanged on non-Android platforms
- **mixes**: Deduplicate most played and forgotten favorites queries
- **aa**: Show now-playing on cold start without browse tap
- **aa**: Keep MediaSession alive across transient empty playlists
- **home**: Fill-width liked albums grid on wide and sync library data

## [1.7.2+58] - 2026-08-22

### Features

- **release**: Generate changelog notes and show them before update
- **home**: Refresh UI with themed zones and editorial-only chip reload

### Bug Fixes

- **library**: Replace hardcoded tab indices with LibraryTab enum
- **android-auto**: Map podcast, episode, and artist YT home shelves

## [1.7.0] - 2026-08-21

### Features

- **explore**: add Charts, Moods, and New Releases UI
- **ytmusic**: wire search, podcasts, users, and v1.7 library APIs
- **ytmusic**: wire v1.6 APIs, native radio, and new releases feed
- **player**: add Charts/Moods to Android Auto Explore and fix mobile action overflow
- **player**: add desktop scroll arrows to related content carousels
- **player/artist**: add related panel and artist videos show-all
- **podcast**: align episodes with library, player, stats, and Android Auto
- **settings**: add configurable media cache size with 1 GB default
- **cache**: store adaptive video as a dual-file pair without FFmpeg
- **cache**: remux adaptive video with FFmpeg Kit on Android and Linux

### Bug Fixes

- **player**: close full player before opening related browse pages
- **player**: wait for async video seek before finishing queue restore
- **player**: restore video playback via HLS when muxed streams are gone

### Other Changes

- **android**: upgrade Gradle/AGP/Kotlin and drop unmaintained plugins
