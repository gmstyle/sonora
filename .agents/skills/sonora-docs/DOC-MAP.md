# Sonora doc map (detail)

Companion to [SKILL.md](SKILL.md). Read this when unsure which section to edit.

## README.md

Typical sections (order may vary slightly):

- Brand / pitch (centered logo, tagline, badge row)
- Screenshots (`screens/`: desktop + tablet table, then one `<details>` per device family — mobile pair, Android TV pair)
- Features (Playback, Library & offline, Explore, Desktop & extras) as `###` headings
- Supported Platforms (Android 11+ / API 30, Android TV, Linux; unsupported platforms on one line)
- Download (Releases table: APK universal + per-ABI, tar.gz, DEB, RPM)
- Getting Started (Prerequisites, Build from source, Headless CLI)
- Development (stack, links to SONORA-DEV-DOCS + DESIGN, checks and regenerate blocks)
- Support (donate)
- License / Disclaimer

Do not reintroduce `---` rules between sections: GitHub already separates headings.
Keep portrait screenshots out of a row that also holds landscape ones.

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
