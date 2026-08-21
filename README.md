<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo_full.svg">
  <img alt="Sonora" src="assets/logo_full.png" width="320">
</picture>

Sonora is a cross-platform music and video streaming app built with Flutter. It uses **YouTube Music** as its data source, offering a rich and customizable experience on **Android** and **Linux desktop**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: Android + Linux](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-blue)
[![Total Downloads](https://img.shields.io/github/downloads/gmstyle/sonora/total.svg)](https://github.com/gmstyle/sonora/releases)
[![Latest Release Downloads](https://img.shields.io/github/downloads/gmstyle/sonora/latest/total.svg)](https://github.com/gmstyle/sonora/releases/latest)

## Donate
If you enjoy Sonora and want to support its development, a small donation is always appreciated:

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/gmstyle)

---

## Screenshots

| Wide (desktop) | Tablet | Mobile |
|----------------|--------|--------|
| ![Home wide](screens/home-wide.png) | ![Player](screens/home-tablet.png) | ![Home mobile](screens/home-mobile.png) |
| ![Settings wide](screens/player-wide.png) | ![Artist](screens/player-tablet.png) | ![Library mobile](screens/player-mobile.png) |

---

## Features

- **YouTube Music streaming** — search, browse, and play songs, albums, artists, playlists, music videos, podcasts, and episodes directly from YouTube Music
- **Explore** — Charts, Moods & Genres, and New Releases with dedicated browse screens
- **Podcasts & episodes** — podcast detail pages, episode detail pages, subscribe/unsubscribe, save episodes, play/shuffle episode queues, and download support
- **User / channel pages** — browse non-artist YouTube Music user channels, their videos, and playlists
- **Related content** — in-player Related panel with similar songs and sections from YouTube Music
- **Background playback** — keep listening/watching while using other apps, with a persistent notification on Android
- **Audio & Video support** — switch between audio-only and video playback seamlessly
- **Android Auto** — driving support with playback controls, Home / Library / Mixes / Explore browse, Charts & Moods, subscribed podcasts, queue split (Playing Next / Up Next), and sleep timer
- **Casting** — stream audio to Chromecast and DLNA devices (WiFi speakers, Smart TVs)
- **Offline downloads & playback** — save songs and podcast episodes locally for offline listening with zero-network local playback support
- **Explicit Offline Mode** — manual switch to override device network status and browse/play locally cached tracks only
- **Connectivity awareness** — global warning banner when offline, automatic connection restoration cues, and friendly network error handling
- **Local library** — save favorite songs, albums, artists, playlists, subscribed podcasts, and saved episodes; create custom playlists
- **YouTube Playlist Syncing** — import and synchronize remote YouTube Music playlists into local database
- **Smart Playlists (Auto-mixes)** — dynamic automatically generated playlists based on listening history (Most Played, Recently Played, Forgotten Favorites)
- **Listening history** — track songs, videos, and podcast episodes (typed history with podcast linkage)
- **Search** — search songs, albums, artists, playlists, music videos, podcasts, episodes, and users
- **5-Band Equalizer** — customize audio gain (-12dB to +12dB) across 5 bands (Bass, Mid-Bass, Mid, Mid-High, High) with pre-built presets managed natively through `media_kit` FFmpeg audio filters
- **Listening Stats & Sonora Wrapped** — offline-first dashboard summarizing total listening time, Top Songs, Top Artists, Top Podcasts, Top Episodes, hourly/weekly listening charts, and a timed Instagram/Spotify-style stories view for sharing your Sonora Wrapped
- **Adaptive UI & Overlays** — optimized layouts for mobile, tablet, and wide screens (NavigationBar / NavigationRail / NavigationDrawer). Temporary panels (Equalizer, Casting, Sleep Timer, Sync Panel) adaptively display as centered dialogs on wide desktops and modal bottom sheets on mobile.
- **Themes** — light, dark, and AMOLED themes, with Dynamic Color support on Android 12+
- **Crossfade** — smooth transitions between songs (configurable duration)
- **Sleep timer** — stop playback after a set time
- **Linux desktop** — system tray, MPRIS global controls (D-Bus), resizable window
- **Auto-update** — automatic update check via GitHub Releases
- **Headless CLI** — control Sonora from the terminal: search, play, download, and manage library without the GUI
- **Backup & restore** — export and import your local library (backup format v3 includes subscribed podcasts and saved episodes)
- **P2P Local Synchronization** — synchronize your music library (likes, playlists, podcasts, episodes, history) peer-to-peer over Wi-Fi between multiple Sonora instances (Android & Linux) without cloud dependencies
- **Localization** — Italian and English

---

## Supported Platforms

| Platform | Status |
|----------|--------|
| Android  | ✅ (API 24+) |
| Linux    | ✅ (x64) |
| Windows  | ❌ (not planned) |
| macOS    | ❌ (not planned) |
| iOS      | ❌ (not planned) |

---

## Tech Stack

| Component | Library |
|-----------|---------|
| **Framework** | Flutter 3.44+ |
| **State Management** | Riverpod 3.x |
| **Navigation** | go_router 17.x |
| **Local Database** | Drift (ex Moor) |
| **Media Playback** | media_kit + audio_service |
| **YouTube Music API** | [dart_ytmusic_api](https://github.com/gmstyle/dart_ytmusic_api) |
| **Stream URL** | youtube_explode_dart |
| **Casting** | dart_cast |
| **Themes** | dynamic_color, palette_generator |
| **Downloads** | Dio |
| **CLI** | args 2.x |
| **Notifications** | flutter_local_notifications |

### Architecture

Clean Architecture with three layers:

```
lib/
├── core/          # Constants, themes, utilities, extensions
├── data/          # Data sources (remote YTM, local Drift) + repository implementations
├── domain/        # Models, repository interfaces, use cases
├── presentation/  # Riverpod providers, widgets, screens, router
└── l10n/          # EN / IT localization
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44+ (stable channel)
- Android Studio (for Android builds)
- Linux: `clang`, `cmake`, `ninja`, `libgtk-3-dev`, `pkg-config`, `libjson-glib-dev` (Debian/Ubuntu) / `json-glib-devel` (Fedora) — required to build `ffmpeg_kit_flutter_new_min` for adaptive video remux

### Build from Source

```bash
git clone https://github.com/gmstyle/sonora.git
cd sonora

# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Generate localizations
flutter gen-l10n

# Run in debug mode
flutter run

# Android release build
flutter build apk --release

# Linux release build
flutter build linux --release
```

### Headless CLI

```bash
curl -fsSL https://raw.githubusercontent.com/gmstyle/sonora/dev/install.sh | bash
sonora search "the beatles" --limit 5
```

See [CLI documentation](docs/CLI.md) for all commands and options.

---

## Download

Download the latest release from [GitHub Releases](https://github.com/gmstyle/sonora/releases/latest):

- **Android**: signed APK ready to install
- **Linux**: `sonora-linux-x64.tar.gz` with install scripts

---

## Development

- [CLI documentation](docs/CLI.md) — headless terminal usage: search, play, download, library, history
- [Developer documentation](docs/SONORA-DEV-DOCS.md) — detailed guide on architecture, database, audio engine, and conventions
- Report bugs or request features via [GitHub Issues](https://github.com/gmstyle/sonora/issues)
- Pull requests are welcome!

### Useful Commands

```bash
flutter analyze                                          # Static analysis
flutter test                                             # Run tests
dart run build_runner build --delete-conflicting-outputs  # Regenerate Drift code
flutter gen-l10n                                         # Regenerate localizations
```

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

## Disclaimer

Sonora is a independent project and is not endorsed by YouTube or Google.
Sonora does not collect any personal data or information, it does not host, distribute or sell any copyrighted material. All content is the property of the respective content owners. Sonora is for educational purposes only. The developer not encourage any illegal activity and not responsible for any illegal use of the software.
