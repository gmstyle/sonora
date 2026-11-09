# Sonora doc map (detail)

Companion to [SKILL.md](SKILL.md). Read this when unsure which section to edit.

## README.md

Typical sections (order may vary slightly):

- Brand / pitch
- Screenshots (`screens/`)
- Donate
- Features (Playback, Library & offline, Explore, Desktop & extras)
- Supported Platforms
- Download (GitHub Releases: APK, tar.gz, DEB, RPM)
- Getting Started / Prerequisites (Flutter stable floor, Linux packages)
- Links to CLI + SONORA-DEV-DOCS

## CHANGELOG.md

- Header: Keep a Changelog + Conventional Commits notice
- Newest release first
- CI insert: `scripts/insert_changelog_entry.py` after release workflow
- Preview: `python3 scripts/generate_release_notes.py`

## docs/SONORA-DEV-DOCS.md

High-level sections (numbers can drift — search headings):

1. Architectural overview + stack table
2. Code structure (`lib/` tree)
3. Domain / data patterns
4–6. Player, queue, cast, Android Auto (as present in file)
7. UI / settings surfaces
8. Distribution & CI/CD (`release.yml`, `act`, packaging)
9+. Further subsystems (sync, cache, etc. as present)

When documenting player work, prefer the facade + controllers narrative already in the file (`SonoraAudioHandler`, `PlaybackRestoreController`, `AndroidAutoBrowserController`, …).

## docs/CLI.md

- Prerequisites, Installation, Usage
- Commands: `search`, `play`, `download`, `library`, `history` (extend if new commands land)
- JSON Output, Supported Players, Database, Examples, Troubleshooting

Source of truth for behavior: `lib/cli/commands/`.
