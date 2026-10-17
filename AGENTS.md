# Sonora

Flutter music app. Catalog comes from YouTube Music through `dart_ytmusic_api`. Stream URLs come from `youtube_explode_dart`. Playback is `just_audio` behind a `PlaybackEngine`. Local data is Drift. Supported clients are **Android and Linux**.

`docs/SONORA-DEV-DOCS.md` is the architecture reference (layers, player, schema, routes). This file is the contract for changes: follow the patterns below instead of inventing a parallel one. `docs/CLI.md` covers the headless CLI.

## Verify

| Command | When |
|---|---|
| `flutter analyze` | After every `lib/` change |
| `flutter test --exclude-tags integration` | After logic or widget behavior changes. Same set CI runs |
| `flutter test --tags integration` | Only when you intend to hit live YouTube Music |
| `dart run build_runner build --delete-conflicting-outputs` | After a Drift table or column change |
| `flutter gen-l10n` | After editing `lib/l10n/app_en.arb` or `app_it.arb` |

Do not hand-edit generated files: `lib/data/datasources/local/database.g.dart`, `lib/l10n/app_localizations*.dart`. Do not add a CHANGELOG version section; CI writes it from Conventional Commits (`feat` / `fix` / `perf`).

## Where a change goes

Three layers. Dependencies point inward.

| Layer | Owns | Must not |
|---|---|---|
| `domain/` | Repository interfaces, use cases, local PODOs (`library_models.dart`, `QueueTrack`) | Flutter, Riverpod, Drift, HTTP |
| `data/` | Drift, DAOs, `YtmusicDatasource`, repository implementations, proxy/cache/cast/sync services | Widgets, providers |
| `presentation/` | Screens, layouts, widgets, Riverpod providers, go_router, the audio handler and its controllers | SQL, Innertube JSON |

YouTube Music models (`SongDetailed`, `AlbumFull`, `PodcastFull`, …) are used as-is. Do not map them into a second DTO. Local rows stay the PODOs in `domain/models/library_models.dart`.

`lib/data/datasources/local/database.dart` is pure Dart so the CLI can open it. The Flutter connection lives in `database_connection.dart`. Do not import Flutter or `drift_flutter` into `database.dart`.

New comments are English. Imports inside `lib/` are relative. `analysis_options.yaml` is `package:flutter_lints`. Fix the files you touched; do not reformat an unrelated screen in the same change.

## Riverpod

State is `flutter_riverpod` 3. Mutable state is a `Notifier` exposed by `NotifierProvider`. Read-only data is `Provider`, `FutureProvider`, or `StreamProvider`. There is no `riverpod_generator`, no `StateNotifier`, no `ChangeNotifier`, and no `package:provider`.

### Who may call a repository

A widget never calls `ref.read` or `ref.watch` on `*RepositoryProvider`. Three legal paths:

1. **Use case** in `domain/usecases/` when the action needs two or more repository or datasource calls. Wire it with a `Provider` next to the other use-case providers (`playAlbumUseCaseProvider`). Playback of an album, playlist, podcast, smart mix, or radio goes through `PlayerNotifier`, which owns the use case call, `isSwitching`, and the monotonic `_operationVersion`.
2. **`LibraryNotifier`** (`libraryNotifierProvider`) for a single library mutation: like, follow, subscribe, playlist entry, history.
3. **`FutureProvider` / `FutureProvider.family`** for a one-to-one read (`albumProvider` → `repo.getAlbum()`).

`StreamProvider.family` is the read side of a Drift watch (`likedSongProvider`, `likedAlbumProvider`, `likedPodcastProvider`, …). Widgets watch those; they do not poll.

### Naming and placement

| Kind | Name | Lives in |
|---|---|---|
| DI or derived read | `somethingProvider` | `presentation/providers/` if app-wide; `features/<feature>/providers/` if one screen owns it |
| Mutable holder | `SomethingNotifier` | Same file as its provider |
| The provider for that holder | `somethingProvider` or `libraryNotifierProvider` | Same file |

Overrides that `main()` must supply throw `UnimplementedError` (`sharedPreferencesProvider`, `audioHandlerProvider`). Do not construct `SharedPreferences` or `SonoraAudioHandler` inside a widget.

### How a widget uses a provider

- `ConsumerWidget` or `ConsumerStatefulWidget`. A `StatelessWidget` is only for a pure layout shell that receives data from a parent (`HomeScreen` selects a width, then `HomeFeedLayout` watches providers).
- `ref.watch` in `build` and inside providers that must rebuild when a dependency changes.
- `ref.read` in callbacks, `Notifier` methods, and one-shot actions. Do not `watch` a notifier just to call a method.
- Async UI is `asyncValue.when(loading:, error:, data:)`. Retry is `ref.invalidate(thatProvider)`.
- `Notifier.build` returns the initial state and may subscribe; cancel with `ref.onDispose`. Replace state with a new immutable value (`state = state.copyWith(...)`). Do not mutate lists inside the current state object.

```dart
// Widget: watch the family, invalidate on retry. No repository here.
final albumAsync = ref.watch(albumProvider(albumId));
return albumAsync.when(
  loading: () => const Scaffold(body: _AlbumShimmer()),
  error: (e, _) => Scaffold(
    body: ErrorRetryWidget(
      message: l10n.failedToLoad,
      onRetry: () => ref.invalidate(albumProvider(albumId)),
    ),
  ),
  data: (album) => _AlbumContent(album: album),
);

// Callback: read the notifier, do not watch it.
onPressed: () => ref.read(libraryNotifierProvider.notifier).toggleLikedSong(song),
```

## UI and UX

Material 3 comes from `AppTheme` (`lib/core/theme/app_theme.dart`). Color is `Theme.of(context).colorScheme` or `PlayerColors`. Type is `textTheme` (Montserrat is already applied). Cards are elevation 0, radius 16, `surfaceContainer`. Dialogs are radius 20. Do not introduce a second font, a raw `Colors.blue`, or a one-off radius.

### Widths

Breakpoints in `lib/core/constants/app_constants.dart`:

| Width | Shell | Feature layout |
|---|---|---|
| `< 600` (`kCompactBreakpoint`) | `MobileShell` — `NavigationBar` | `*_mobile_layout.dart` |
| `600–1200` | `TabletShell` — collapsed `NavigationRail` | `*_tablet_layout.dart`. `kMediumBreakpoint` (840) is an internal split, not a new shell |
| `≥ 1200` (`kExpandedBreakpoint`) | `WideShell` — navigation drawer | `*_wide_layout.dart` |

A feature screen is a `LayoutBuilder` that picks one of those three. Home shelves use `HomeLayoutMetrics` (padding 16 / 24 / 32, card widths 140 / 160 / 180). Reuse that scale. Do not add a fourth breakpoint.

Shell routes are the indexed stack in `router.dart`: Home `/`, Search `/search`, Library `/library`, Downloads `/downloads`. Settings is a sibling `GoRoute` on the root navigator, opened with `context.push`, not a fifth tab. Sub-routes (artist, album, playlist, podcast, episode, user, charts, moods) hang off the current branch. The player is an overlay above the shell, not a route. Do not add `/player`.

Mobile fuses the mini player with the `NavigationBar` into one dock. Tablet and wide use a floating mini player. `NavNowPlaying` shows identity only (no transport). Catalog context in that row navigates to the album, artist, or podcast.

### Detail headers and menus

Album, YouTube playlist, artist, podcast, and local playlist headers use `DetailActionsBar`. Do not add a second action row.

| Width | Bar |
|---|---|
| Compact | Queue + Save icons + Shuffle + ⋮ + circular Play |
| Tablet and wide | Play + Shuffle + Queue + Save (labeled) + ⋮ |

`onOverflow` passes `omitActionIds` for actions already in the bar. Long-press and list menus use the full sheet (empty omit set). Entity menus are `ContextMenuSheet.showForSong` / `showForArtist` / `showForAlbum` / `showForPodcast` / `showForEpisode` / `showForPlaylist` / `showForCustomPlaylist` / `showForNowPlaying`.

Affinity controls are `DetailAffinityButton`:

| Action | Icon | Active color |
|---|---|---|
| Like (song, album, YouTube playlist) | Material `favorite_border` → `favorite` | `colorScheme.error` |
| Follow (artist) | Lucide `userPlus` → `userCheck` | `colorScheme.primary` |
| Subscribe (podcast) / save episode | Lucide `bookmark` → `bookmarkCheck` | `colorScheme.primary` |

Product chrome icons are Lucide (`lucide_icons_flutter`). Like stays Material `favorite`. Do not add a third icon set.

### Overlays, feedback, and states

Temporary panels follow the width:

- Under 1200: `showModalBottomSheet`.
- 1200 and above: centered `showDialog` with a max width and an explicit close.

Equalizer, local sync, cast, and the sleep timer already do this. Playlist import is the exception: full-width sheet under 600, dialog locked at 480 between 600 and 1200, dialog locked at 560 at 1200 and above. A long pasted URL must not resize the card.

| Situation | Widget |
|---|---|
| Loading a list or detail | Existing shimmer in `shared/widgets/shimmer_loading.dart` |
| Empty collection | `EmptyStateWidget` |
| Failed load | `ErrorRetryWidget` + `ref.invalidate` |
| Confirm or soft failure ("Added to queue") | `ref.read(actionFeedbackProvider.notifier).report(l10n....)` |
| Offline | `OfflineBanner` (already in `AppShell`) |
| Persistent progress above the dock (downloads, playlist import, …) | `DockProgressBanner` via `DockStatusBanners` in the three shells. Do not invent a second chip chrome |

`report` copy comes from `AppLocalizations`. Exception text goes to `debugPrint`, not the toast. In release, sync and network failures show a localized message; `kDebugMode` is the only place a raw error may reach the UI.

When `isOfflineProvider` is true, disable network CTAs: radio, download, cast, search submit, autoplay, related, sync. Like, follow, subscribe, and local playlists stay enabled. `isOfflineProvider` is settings offline **or** `ConnectivityResult.none`. It does not DNS-probe.

Unplayable catalog rows stay in the list, dimmed, with a ban icon. Hide play, queue, radio, download, and add-to-playlist. `PlayAlbumUseCase` / `PlayPlaylistUseCase` drop them. Use `lib/core/utils/playable_tracks.dart`.

New motion and heavy artwork respect `Settings.reduceEffects`. Vinyl artwork respects `Settings.useVinylStyle`.

### Copy

User-visible strings go in `lib/l10n/app_en.arb` (template) and `app_it.arb`, then `flutter gen-l10n`. Read them with `AppLocalizations.of(context)!`. Do not add a new hardcoded English label. Counts from the API use `int.toCompact()` or `stripYtLabel()` (`lib/core/extensions/stat_format.dart`), not a new formatter.

## Playback

UI calls `PlayerNotifier`. It calls `SonoraAudioHandler`. The handler delegates to controllers. Controllers take a `PlaybackEngine` and narrow callbacks; they do not keep a reference to the handler, and they do not read Riverpod.

- Do not call `just_audio` from a widget. The engine is `JustAudioPlaybackEngine`.
- Do not resolve a stream URL in a widget. `PlayVideoIdUseCase.resolveUrl` is the playback URL entry. Lookahead and the disk cache go through `TrackUrlResolver` and `MediaCacheService`. `LockCachingAudioSource` is not used.
- Shuffle is `SkipNavigator`. `just_audio_media_kit` ignores `shuffleOrder`.
- Queue sections are `extras['section']` of `'user'` or `'upnext'`. Retag only inside `QueueController`.
- `contentType` is `song`, `video`, or `episode`. Episode likes, history, lyrics, and show notes branch on `QueueTrack.isEpisode`.
- A new play path must participate in `_operationVersion` so a fast second tap drops the stale open.

## Data

A Drift change is four steps: table file, `@DriftDatabase` list, `schemaVersion` bump plus `onUpgrade`, then `build_runner`. Current schema is **v25**. Backup JSON is version 3 (`ExportBackupUseCase`). A new library collection is added to export, import, and `MergeLibraryUseCase` together.

Portable preferences go through `Settings.toBackupMap` / `applyBackupMap` (equalizer through `EqualizerState`). Device-local keys (`downloadPath`, `wrappedSeen`, runtime flags) stay out of the backup map.

Catalog fields that are not already columns (subscriber counts, descriptions, play counts) are displayed from the API response and not written to SQLite.

## Scope

Android and Linux only. Do not add iOS, Windows, or macOS targets, permissions, or copy. In-app video playback was removed; music videos play as audio.

Fix the layer that owns the bug. Do not restyle an unrelated screen, rename a public route, or swap the audio engine in the same change.

Before finishing:

1. The widget reads a provider, not a repository.
2. New copy exists in both ARB files and the generated localizations were regenerated.
3. A new screen handles compact, tablet, and wide, or it is a single adaptive layout that already branches on those widths.
4. A new network action is disabled under `isOfflineProvider`.
5. `flutter analyze` is clean on the edited Dart files. Behavior changes have a test next to the existing group, not a live YouTube call.
