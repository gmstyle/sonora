---
name: sonora-docs
description: >-
  Maintains Sonora project documentation (README, CHANGELOG, docs/SONORA-DEV-DOCS.md,
  docs/CLI.md) in sync with code and release conventions. Use when updating docs,
  documenting a feature, editing README/CHANGELOG/CLI/dev docs, after architecture
  changes, or when the user asks to refresh project documentation.
---

# Sonora documentation maintenance

Keep project docs accurate, concise, and role-separated. Prefer editing existing sections over adding new top-level files.

## Document map

| File | Audience | Purpose |
|------|----------|---------|
| [README.md](../../../README.md) | Users / GitHub visitors | Product overview, platforms, download, getting started, feature highlights |
| [CHANGELOG.md](../../../CHANGELOG.md) | Users + release history | Keep a Changelog entries; primarily filled by CI after releases |
| [docs/SONORA-DEV-DOCS.md](../../../docs/SONORA-DEV-DOCS.md) | Contributors | Architecture, layers, player/AA/cast, DB, CI/release pipeline |
| [docs/CLI.md](../../../docs/CLI.md) | CLI users | Headless CLI install, commands, JSON output |

For section-level anchors and “what goes where”, see [DOC-MAP.md](DOC-MAP.md).

## Language and tone

- All four docs are **English**.
- README / CHANGELOG: user-facing, no internal class names unless unavoidable.
- SONORA-DEV-DOCS: precise technical English; name real packages, paths, and types.
- Do not invent features, platforms, or versions not present in the codebase/`pubspec.yaml`.

## When to update which file

After a change, touch only the docs that need it:

| Kind of change | README | CHANGELOG | SONORA-DEV-DOCS | CLI.md |
|----------------|--------|-----------|-----------------|--------|
| User-visible feature / platform / download | Yes (Features / Supported Platforms / Download) | No (CI) | Yes if architecture/API surface | If CLI affected |
| Internal refactor / bugfix (no UX) | No | No (CI) | Yes if structure/contracts change | No |
| New CLI command / flag | Link only if needed | No (CI) | Point to CLI.md if structure changes | **Yes** |
| Release / version bump | Prerequisites Flutter version if changed | **CI owns insert** | Flutter/stack table if changed | Prerequisites if Flutter floor changes |
| Screens / branding only | Screenshots section | No | No | No |

## README rules

- Keep the first screen product-focused: logo, short pitch, platforms, features, download.
- Features: short bullets grouped as today (Playback / Library / Explore / Desktop & extras).
- Supported Platforms table must stay truthful (Android + Linux yes; Windows/macOS/iOS not planned unless product decision changes).
- Link to `docs/CLI.md` and `docs/SONORA-DEV-DOCS.md` instead of duplicating them.
- Do not paste long architecture dumps into the README.

## CHANGELOG rules

- Format: [Keep a Changelog](https://keepachangelog.com/) + Conventional Commits categories (`Features`, `Bug Fixes`, `Other Changes`).
- **Do not hand-write a new version section for a normal release** unless the user explicitly asks. CI runs `scripts/generate_release_notes.py` and `scripts/insert_changelog_entry.py` after GitHub Release (see SONORA-DEV-DOCS §8).
- Preview notes locally with: `python3 scripts/generate_release_notes.py`
- Only `feat` / `fix` / `perf` commits appear in generated notes; `docs`/`chore`/`ci`/`test`/`refactor` are omitted on purpose.
- If manually editing: match existing heading style `## [{version}+{build}] - YYYY-MM-DD` and scoped bullets (`**area**: …`).

## SONORA-DEV-DOCS rules

- Single source of truth for architecture, `lib/` tree, player/AA/cast, Drift schema notes, release/CI.
- When code moves (new controller, new table, new AA browse node): update the matching section and the structure tree if paths changed.
- Keep stack versions aligned with `pubspec.yaml` / lock where the doc cites them.
- Prefer updating an existing section over appending a disconnected essay at the end.
- Cross-link CLI details to `docs/CLI.md` rather than copying command docs.

## CLI.md rules

- Document every user-facing command and important flags.
- Keep Prerequisites / Installation / Examples working for Linux.
- If command output JSON shape changes, update the JSON Output section.
- Stay consistent with `lib/cli/` implementations — read the command file before editing.

## Maintenance workflow

Copy and track:

```
Doc update:
- [ ] Identify change impact (user / architecture / CLI / release)
- [ ] Edit only the relevant file(s) from the map above
- [ ] Verify links between README ↔ docs still resolve
- [ ] No contradictory platform or version claims
- [ ] Do not commit secrets, keystores, or local paths
```

1. Read the current section before rewriting.
2. Diff against code (`lib/`, `pubspec.yaml`, `scripts/`) when unsure.
3. Keep edits minimal and scoped (same rule as code changes).
4. If the user asked only for code, **do not** expand docs unless they ask — except when they explicitly request documentation maintenance.

## Anti-patterns

- Duplicating the full architecture into README.
- Adding iOS/Windows/macOS as supported without an explicit product decision.
- Inventing CHANGELOG versions ahead of CI.
- Leaving stale paths after renames under `lib/presentation/features/player/`.
- Mixing Italian into these English docs.
