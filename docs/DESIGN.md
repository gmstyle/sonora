# Sonora Pulse

Visual contract for the Flutter app. Source: Stitch project **Sonora UI UX Redesign**, design system **Sonora Pulse** (dark + light). Tokens in code live in `lib/core/theme/sonora_pulse_tokens.dart` and are applied by `AppTheme`.

Android and Linux only. The player overlay is not a route. Three width breakpoints stay as in `AGENTS.md`.

## Brand

The logomark is a vertical equalizer in a cyan-to-azure gradient. Dark mode is a cosmic indigo field with glass surfaces. Light mode is a studio canvas (`#F5F7FB`) with white cards and the same gradient on playback controls.

Brand fills:

- Vertical (equalizer, play control): `#00F2FE` → `#4FACFE`
- Horizontal (scrubber, badges): `#00F2FE` → `#4FACFE`

**Do not fill controls with dark `primary` (`#E0FDFF`).** That role is a light tint for labels and selected text. Circular play overlays, FABs, scrubbers, and status badges use `primaryContainer` / `SonoraPulseTokens.playControlDecoration` with `onPrimary` (`#00373A`) for the glyph. Glyphs sitting on brand gradient art use `onBrandGraphic` (white).

There is no Monet / dynamic color. Wallpaper does not recolor the scheme.

## Color

### Dark (default `ColorScheme`)

| Role | Hex |
|------|-----|
| surface / background | `#101127` |
| surface-container-lowest | `#0B0C22` |
| surface-container-low | `#181930` |
| surface-container | `#1D1E34` |
| surface-container-high | `#27283F` |
| surface-container-highest | `#32334A` |
| on-surface | `#E1E0FF` |
| on-surface-variant | `#B9CACB` |
| outline | `#849495` |
| outline-variant | `#3A494B` |
| primary | `#E0FDFF` |
| on-primary | `#00373A` |
| primary-container | `#00F2FE` |
| on-primary-container | `#006A70` |
| secondary | `#9BCBFF` |
| secondary-container | `#3196E6` |
| tertiary | `#FAF6FF` |
| tertiary-container | `#DAD7FF` |
| error | `#FFB4AB` |

Atmosphere canvas (shell / full player, 45°): `#0F1026` → `#1A1B35` → `#2D2F54`.

Elevated glass: `#141527` at 80% (cards), `#1E2038` at 90% (player shelf, dialogs). Border `#2D2F54` at 60%. Active controls glow `rgba(0, 242, 254, 0.35)`.

AMOLED mode keeps this palette and forces `surface` and the scaffold to `#0B0C22`.

### Light

| Role | Hex |
|------|-----|
| canvas / surface | `#F5F7FB` |
| card / surface-container-lowest | `#FFFFFF` |
| panel / surface-container | `#EDF2F7` |
| border / outline-variant | `#E2E8F0` |
| on-surface | `#0F172A` |
| on-surface-variant | `#475569` |
| primary (readable teal) | `#00696F` |
| primary-container (brand cyan) | `#00F2FE` |
| secondary | `#2563EB` |
| tertiary | `#4F46E5` |

Home ambient: light uses the solid studio canvas (`#F5F7FB`) plus an optional 4–5% cyan→azure wash — never the blurred YouTube photo. Dark keeps the photo/palette atmosphere (skipped when `reduceEffects` is on).

Player overlay colors stay dark regardless of theme. They live on `PlayerColors`: white titles, slate subtitles (`#94A3B8`), indigo scrim (`#0F1026`), cyan accent `#00F2FE`.

## Type

Plus Jakarta Sans via `google_fonts`, on every text role.

| Token | Size | Weight | Tracking |
|-------|------|--------|----------|
| display-lg | 40 | 800 | -0.02em |
| display-lg-mobile | 30 | 800 | -0.015em |
| headline-lg | 28 | 700 | -0.01em |
| headline-lg-mobile | 22 | 700 | -0.01em |
| headline-md | 20 | 700 | -0.005em |
| title-lg | 17 | 600 | — |
| title-md | 15 | 600 | — |
| body-lg | 15 | 400 | — |
| body-md | 13 | 400 | — |
| label-lg | 13 | 600 | 0.01em |
| label-md | 11 | 500 | 0.02em |
| label-sm | 10 | 700 | 0.06em |

## Shape and spacing

4px base. Desktop rhythm is 8px / 20px.

| Token | Value | Use |
|-------|-------|-----|
| pill / full | 9999 | Buttons, chips, search |
| media | 24 | Album, playlist, and mix cards |
| sm | 12 | Track rows |
| dialog | 20 | Dialogs (tighter than media cards) |
| gutter | 20 | Mobile shelves |
| gutter-desktop | 24 | Desktop shelves |
| margin | 16 | Mobile page inset |
| margin-desktop | 32 | Desktop page inset |

## Chrome

- **Wide:** sidebar 72px collapsed / 240px expanded. No now-playing block in the sidebar. Mini player is an 80px edge-to-edge shelf under sidebar and content. Art sits on the left of that shelf.
- **Tablet:** collapsed rail, same full-width 80px shelf.
- **Mobile:** mini player stays fused with the bottom navigation. Restyle uses Pulse cyan and pill geometry. Navigation bar height is 64.

`reduceEffects` drops blur and heavy motion. `useVinylStyle` still controls the circular art stage. Like stays Material `favorite`. Other chrome icons stay Lucide.

Do not add a Soundscape AI column, a lossless badge, or a multi-band waveform scrubber.
