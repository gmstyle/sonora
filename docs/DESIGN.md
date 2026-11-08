# Sonora Pulse

Visual contract for the Flutter app. Source: Stitch project **Sonora UI UX Redesign**, design system **Sonora Pulse** (dark + light). Tokens in code live in `lib/core/theme/sonora_pulse_tokens.dart` and are applied by `AppTheme`.

Android and Linux only. The player overlay is not a route. Three shell breakpoints stay as in `AGENTS.md`. `kWideContentBreakpoint` (1600) is an internal content split inside the wide shell, not a fourth shell.

## Brand

The logomark is a vertical equalizer in a cyan-to-azure gradient. Dark mode is a cosmic indigo field with glass surfaces. Light mode is a studio canvas (`#F5F7FB`) with white cards and the same gradient on playback controls.

Brand fills:

- Vertical (equalizer, play control): `#00F2FE` → `#4FACFE`
- Horizontal (scrubber, badges): `#00F2FE` → `#4FACFE`

Dark `ColorScheme.primary` is brand cyan (`#00F2FE`) so Material filled controls (FAB, Switch, `IconButton.filled`, `FilledButton`, …) get a readable fill with `onPrimary` (`#00373A`). Ice (`#E0FDFF`) is `SonoraPulseTokens.primaryTint` for TextButtons and quiet label accents — never a solid control fill. `FilledButtonTheme` must not set fill/foreground colors: it also applies to `FilledButton.tonal` (Follow / Like / Shuffle), which must keep `secondaryContainer`. Circular play overlays use `playControlDecoration` with `onPrimary` for the glyph. Glyphs on brand gradient art use `onBrandGraphic` (white).

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
| primary | `#00F2FE` (brand fill; Material interactive) |
| on-primary | `#00373A` |
| primary-container | `#00F2FE` |
| on-primary-container | `#00373A` |
| primaryTint (token, not a ColorScheme role) | `#E0FDFF` (ice labels) |
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
| gutter | 16 | Mobile shelves (`kCompactContentPadding`) |
| gutter-desktop | 24 | Desktop shelves |
| margin | 16 | Mobile page inset |
| margin-desktop | 32 | Desktop page inset |

## Chrome

- **Wide:** sidebar 72px collapsed / 240px expanded. No now-playing block in the sidebar. Mini player is an 80px edge-to-edge shelf under sidebar and content. Art sits on the left of that shelf.
- **Tablet:** collapsed rail, same full-width 80px shelf.
- **Mobile:** mini player is a floating card above the bottom navigation. The card uses the media radius, a 95% surface with blur, and the brand gradient on the 2px seek strip. Navigation bar height is 64.

`reduceEffects` drops blur and heavy motion. `useVinylStyle` still controls the circular art stage. Like stays Material `favorite`. Other chrome icons stay Lucide.

Affinity (like, follow, subscribe, save episode) uses one rule on compact, tablet, and wide: swap the icon pair and tint the glyph (and the labeled tonal text) with `primary`. The tonal fill stays `secondaryContainer`. Idle glyphs are `onSurfaceVariant`. The heart, person, and bookmark pairs distinguish the action. `error` stays on destructive actions and error states.

Other controls share five intents:

| Intent | Widget | Selected / pressed |
|---|---|---|
| Commit | `FilledButton` | `primary` fill, `onPrimary` glyph (Play) |
| Companion | `FilledButton.tonal` | `secondaryContainer` fill (Shuffle, Queue, affinity). Active affinity tints the glyph only |
| Quiet | `TextButton` | No fill. Dark label is `primaryTint` |
| Select | `FilterChip`, `ChoiceChip`, `SegmentedButton` | 28% `primaryContainer` fill, `primary` label, no checkmark. Idle label is `onSurfaceVariant` |
| Binary | `Switch` | `primary` track, `onPrimary` thumb |

Do not add a Soundscape AI column, a lossless badge, or a multi-band waveform scrubber.

## Wide content families

`WideShell` (sidebar + 80px mini shelf) does not change at 1600. Only the **content** switches shape. `kWideContentBreakpoint` decides whether the facet utility rail is present. It does not add a layout file or a shell.

Shell family selection matches `AppShell`: compact when `shortestSide < 600` (`isCompactShell`), then tablet vs wide on window width. Content boxes still measure padding and rails from `LayoutBuilder`. Landscape phones stay on mobile family layouts (pad 16, max 2 feed columns, icon `DetailActionsBar`, Library chips — not the tablet split).

### Mobile

`MobileShell` keeps the `NavigationBar` (64) as the dock. The mini player is a separate card above it: 60 tall, inset `kCompactContentPadding`, with an 8 gap above the bar. Light fill is `surfaceContainerLowest` at 95%. Dark fill is `surfaceContainerLow` at 95% with `darkBorder`. Artwork is 44 at radius 12. Like and the gradient play control sit on the right. There is no master rail and no utility rail. The four families stay stacked and chip-driven.

| Rule | Mobile (`shortestSide` &lt; 600) |
|------|--------------------------------|
| Horizontal pad | `kCompactContentPadding` (16) |
| Master / utility rail | None |
| Feed columns | Always 2, even when content width is ≥ 600 (landscape) |
| Facet | Horizontal chips (Library, Downloads, Search) — not a tablet master–detail split |
| Entity | Stacked header and list. Icon `DetailActionsBar` (not labeled) |
| Document | Settings is a category list that pushes detail — no master rail |

Home carousels stay on `HomeLayoutMetrics` mobile (pad 16, card 140).

### Tablet

`TabletShell` stays the collapsed rail and the 80px shelf. The same four families use a tighter budget. There is no utility rail under 1200. Compact layouts stay on the 16 inset.

| Rule | Tablet (600–1199, `shortestSide` ≥ 600) |
|------|-----------------------------------------|
| Horizontal pad | `kTabletContentPadding` (24) |
| Master rail | `kFacetFilterRailWidth` (200) for Library, Downloads, and Settings |
| Feed columns | 3 when the content box is under `kFeedFourColumnContentWidth` (800); 4 from 800 until the wide splits. 800 is a content-box threshold, not a shell |
| Search | Horizontal chips |
| Entity | Stacked header and list at pad 24. No track-list cap |
| Document | Master rail 200. The 1320 clamp is wide-only |

Home carousels stay on `HomeLayoutMetrics` (pad 24, card 160).

Tokens live in `lib/core/constants/app_constants.dart`:

| Token | Value | Use |
|-------|-------|-----|
| `kWideContentBreakpoint` | 1600 | Internal split for the facet utility rail. Not a shell |
| `kFeedFourColumnContentWidth` | 800 | Content-box width where feed grids go from 3 columns to 4. Not a shell |
| `kFacetFilterRailWidth` | 200 | Facet and tablet master rail |
| `kFacetUtilityRailWidth` | 280 | Facet right rail at ≥1600 |
| `kDocumentContentMaxWidth` | 1320 | Document soft max on wide |
| `kWideContentPadding` | 32 | Horizontal pad for wide feed, facet, and entity. Same inset as margin-desktop |
| `kTabletContentPadding` | 24 | Horizontal pad on tablet |
| `kCompactContentPadding` | 16 | Horizontal pad on compact / MobileShell |

### Feed

Edge-to-edge shelves and grids. Horizontal padding is `kWideContentPadding` (32). Column count follows the content width. Do not wrap the page in `Center` plus a `maxWidth`.

Screens: Home, Charts, Moods (including mood playlists), New releases, Browse section.

Home mood chips sit in the `AppBar` bottom on compact, tablet, and wide, and stay pinned while the feed scrolls. All is the personal home: resume, Explore, your music, discover, then the default shelves with no extra zone title. A selected chip replaces that body with that mood's shelves, scrolls to the top, and shows a shelf shimmer while the feed loads. Explore (charts, moods, new releases) stays on All. The chip row hides while offline.

### Facet

Left filter rail `kFacetFilterRailWidth` (200), a fluid center with padding 32, and at ≥1600 a right utility rail `kFacetUtilityRailWidth` (280). Do not wrap the page in `Center` plus a `maxWidth`, and do not put the wide page in a `Card`. Library search results stay in the library facet pane.

Screens: Search, Library, Downloads.

### Entity

The artist photo header (sharp photo, no second portrait) is used on compact as well as tablet and wide: the picture itself, with a dark gradient so the name stays readable. On tablet and wide, entity headers share one banner and `DetailActionsBar` sits on its bottom edge. On compact the artist actions stay in the body. Album, playlist, podcast, episode, and profile stay the color-field banner on tablet and wide only: a flat field in the cover's dominant color, the cover on the left (radius 24, circle for a profile), and the name on the right. Compact for those stays the centered header. There is no second action row. Artist stats are three figures (subscribers, monthly listeners, total views) under the name. The biography sits under the actions and spans the content width. The body is one column at every width: biography, the first five popular songs, the newest dated studio album, discography, similar artists, then featured playlists. Vedi tutto on Popular opens the full song list. Vedi tutto on Featured opens the full playlist grid, the same kind of grid as albums and singles. Mostra altro stays on the biography. Discography is one shelf with chips for albums, singles, and videos. Similar artists and featured playlists are horizontal shelves. Album notes sit under the actions, and the track list keeps the number, title, and duration. Notes, the track or episode list, and related shelves share one full-width column. Related releases and profile playlists stack under the list. Tablet uses the same stack.

Screens: Album, artist, YouTube playlist, local playlist, podcast, episode, moment mix, user.

### Document

On wide, this is the only family that clamps the page: soft max `kDocumentContentMaxWidth` (1320) and horizontal padding 32. Settings keeps its card shell (a form surface, not a feed).

Screens: Settings, artist see-all (albums, singles, videos).

The full player overlay and Sonora Wrapped stay immersive. They are not one of these families. Compact full player keeps the original column: the center shows the disc and the up-next card, and lyrics, queue, related, notes, and insights replace that center. Tablet follows the same now-playing page: the current disc, with the previous and next covers set apart, then a single column of artist, album, and related. The mini-player shelf shows the expand control. Lyrics replace that scroll as large left-aligned lines: the current line is white and the others stay muted. Notes replace that scroll. The queue panel is 300. Curiosities use the same edge, capped at half the window (320–420), and close the queue while they are open. Both panels are the same surface card as artist and album (`surfaceContainer`, radius 24, inset from the edge) and slide in from the right. The bottom bar keeps the three zones, with compact action icons. Wide follows a desktop now-playing screen. The canvas scrolls as a pinned sliver: the current disc fills the first screen and collapses into a glass bar with the track title. The previous and next covers sit apart on either side. Below that, two columns. Artist and album share the left column. Related is the right column, so the related action is absent from the wide bar. Lyrics replace that scroll as large left-aligned lines: the current line is white and the others stay muted. Notes replace that scroll. The queue is a right panel (320 below `kWideContentBreakpoint`, 380 from that split). Curiosities use the same edge, wider (480 and 560), and close the queue while they are open. Both use `PlayerSurfaceCard` and slide in from the right. The bottom bar is three equal zones: track info on the left, seek and transport in the center, actions on the right.
