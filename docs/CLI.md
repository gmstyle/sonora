# Sonora CLI

Headless command-line interface for Sonora — search, play, download, and manage your YouTube Music library from the terminal without launching the Flutter GUI.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Commands](#commands)
  - [`search`](#search)
  - [`play`](#play)
  - [`download`](#download)
  - [`library`](#library)
  - [`history`](#history)
- [JSON Output](#json-output)
- [Supported Players](#supported-players)
- [Database](#database)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Flutter SDK 3.44+** (includes Dart SDK) — required to resolve dependencies and generate Drift files
- System dependencies for Flutter Linux:

```bash
sudo dnf install ccache cmake ninja-build gtk3-devel pkg-config \
  lz4-devel libX11-devel mesa-libGL-devel libxkbcommon-devel libatomic
```

- **Audio player** (optional, for `play`): `mpv`, `ffplay` (ffmpeg) or `vlc`

```bash
sudo dnf install mpv
```

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/gmstyle/sonora.git
cd sonora
```

### 2. Install Dart/Flutter dependencies

```bash
flutter pub get
```

### 3. Generate Drift files

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Activate the `sonora` command globally (optional but recommended)

```bash
dart pub global activate --source path .
```

Make sure `~/.pub-cache/bin` is in your `PATH`. Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 5. Verify

```bash
sonora --help
```

If you haven't activated the command globally, use:

```bash
dart run bin/sonora.dart --help
```

---

## Usage

Once activated globally:

```bash
sonora <command> [options]
```

Alternatively, from the project directory:

```bash
dart run bin/sonora.dart <command> [options]
```

All commands support `--help` (or `-h`) to show available options:

```bash
sonora search --help
sonora play --help
```

---

## Commands

### `search`

Search for songs, albums, artists, playlists or videos on YouTube Music.

```
sonora search <query> [--type type] [--limit N] [--json]
```

| Option | Description | Default |
|--------|-------------|---------|
| `query` | Search term (positional, required) | — |
| `--type`, `-t` | Filter: `song`, `album`, `artist`, `playlist`, `video` | `song` |
| `--limit`, `-l` | Max results | `10` |
| `--json` | JSON output | — |

Each result shows its ID on a separate line so you can copy it for use with `play`, `download` or `library`.

**Examples:**

```bash
sonora search "the beatles" --limit 5
sonora search "queen" --type artist --limit 3
sonora search "jazz" --type album --limit 10 --json
```

---

### `play`

Play a song from YouTube Music using an external player (or print the stream URL).

```
sonora play <videoId> [--player auto|mpv|ffplay|vlc|url]
```

| Option | Description | Default |
|--------|-------------|---------|
| `videoId` | YouTube video ID (positional, required) | — |
| `--player` | Player to use | `auto` |

**`--player` values:**

| Value | Behavior |
|-------|----------|
| `auto` | Auto-detects `mpv` → `ffplay` → `vlc`, uses the first found |
| `mpv` | Uses `mpv --no-video --quiet` |
| `ffplay` | Uses `ffplay -nodisp -autoexit -loglevel quiet` |
| `vlc` | Uses `vlc --intf dummy --play-and-exit --no-video` |
| `url` | Prints the stream URL only, no player launched |

**Examples:**

```bash
sonora play "mQER0A0ej0M"
sonora play "mQER0A0ej0M" --player ffplay
sonora play "mQER0A0ej0M" --player url
```

> **Note:** the `videoId` is shown in `sonora search` results.

---

### `download`

Download a song locally.

```
sonora download <videoId> [--title title] [--artist artist] [--output-dir path]
```

| Option | Description | Default |
|--------|-------------|---------|
| `videoId` | YouTube video ID (positional, required) | — |
| `--title` | Custom title (auto-resolved if omitted) | — |
| `--artist` | Custom artist name (auto-resolved if omitted) | — |
| `--output-dir` | Output directory | Current directory |

The file is saved as `<title>-<videoId>.<ext>`.

**Examples:**

```bash
sonora download "mQER0A0ej0M"
sonora download "mQER0A0ej0M" --output-dir ~/Music
sonora download "mQER0A0ej0M" --title "Hey Jude" --artist "The Beatles"
```

---

### `library`

Manage your local library (shared with the GUI).

```
sonora library list [--type songs|albums|artists|playlists] [--json]
sonora library add --type song|album|artist|playlist --id <id> [--title ...] [--artist ...]
sonora library remove --type song|album|artist|playlist --id <id>
```

#### `list`

List saved library items.

| Option | Description | Default |
|--------|-------------|---------|
| `--type` | Item type: `songs`, `albums`, `artists`, `playlists` | `songs` |
| `--json` | JSON output | — |

```bash
sonora library list
sonora library list --type albums
sonora library list --type playlists --json
```

#### `add`

Add an item to the library.

| Option | Description | Required |
|--------|-------------|:--------:|
| `--type` | Type: `song`, `album`, `artist`, `playlist` | ✓ |
| `--id` | Item ID | ✓ |
| `--title` | Title | |
| `--artist` | Artist name | |

```bash
sonora library add --type song --id "mQER0A0ej0M" --title "Hey Jude" --artist "The Beatles"
sonora library add --type artist --id "UC..." --title "Radiohead"
```

#### `remove`

Remove an item from the library.

| Option | Description | Required |
|--------|-------------|:--------:|
| `--type` | Type: `song`, `album`, `artist`, `playlist` | ✓ |
| `--id` | Item ID | ✓ |

```bash
sonora library remove --type song --id "mQER0A0ej0M"
sonora library remove --type artist --id "UC..."
```

---

### `history`

View or clear listening history.

```
sonora history [--limit N] [--clear] [--json]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--limit`, `-l` | Max entries | `20` |
| `--clear` | Clear all history | — |
| `--json` | JSON output | — |

**Examples:**

```bash
sonora history
sonora history --limit 5
sonora history --clear
sonora history --limit 10 --json
```

---

## JSON Output

All commands support `--json` for structured output, ideal for scripting and pipelines. Example:

```bash
sonora search "the beatles" --type song --limit 3 --json
```

Output:

```json
{
  "command": "search",
  "type": "song",
  "results": [
    {
      "videoId": "mQER0A0ej0M",
      "title": "Hey Jude",
      "artist": "The Beatles",
      "album": "Hey Jude",
      "duration": "7:11"
    }
  ]
}
```

---

## Supported Players

| Player | Installation (Fedora) | Notes |
|--------|------------------------|-------|
| **mpv** | `sudo dnf install mpv` | Lightweight, fast startup, stable |
| **ffplay** | `sudo dnf install ffmpeg` | Often already installed |
| **vlc** | `sudo dnf install vlc` | Widely available |

Auto-detection (`--player auto`) tries `mpv` → `ffplay` → `vlc` in order and uses the first one found.

---

## Database

The CLI shares the same SQLite database (`sonora.sqlite`) with the GUI. The database is located at:

- **Linux:** `~/.local/share/sonora/sonora.sqlite`

This means:
- Songs added to the library via CLI are visible in the GUI and vice versa
- Listening history is unified
- Downloads are tracked consistently

---

## Examples

### Search and play a song

```bash
sonora search "radiohead karma police" --limit 1
sonora play <videoId> --player mpv
```

### Add a song to the library and play it

```bash
sonora search "nirvana" --type song --limit 5 --json
sonora library add --type song --id "hTWKbfoikeg" --title "Smells Like Teen Spirit" --artist "Nirvana"
sonora play "hTWKbfoikeg"
```

### Download an entire album (knowing the videoIds)

```bash
sonora download "videoId1" --output-dir ~/Music/Album
sonora download "videoId2" --output-dir ~/Music/Album
```

### Script: backup library to JSON

```bash
sonora library list --type songs --json > library.json
sonora history --json --limit 100 > history.json
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `dart: command not found` | Dart SDK not installed | Install Flutter SDK or standalone Dart |
| `sonora: command not found` | Command not activated globally | Use `dart run bin/sonora.dart` or run `dart pub global activate` |
| `Initialization failed` | No internet or YouTube Music API unreachable | Check your internet connection |
| `Player not found` | No audio player installed | Install `mpv` or use `--player url` |
| `Illegal instruction` | Old CPU without AVX support | Use an external player with `--player url` |
| Compile error `/usr/lib64/ccache` | `ccache` uninstalled but still in PATH | `sudo dnf install ccache` |
