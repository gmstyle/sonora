# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/).

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
