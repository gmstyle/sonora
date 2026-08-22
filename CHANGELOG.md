# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/).

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
