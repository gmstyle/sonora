# Implementation Plan - Evolutionary Enhancements for Sonora

We will implement the four approved evolutionary features: Stream Caching via `media_kit`, Explicit Offline Mode setting, YouTube Playlist Syncing, and Smart Playlists (Auto-mixes).

## User Review Required

> [!NOTE]
> - **Stream Caching**: We will utilize `media_kit`'s underlying `NativePlayer` options to cache audio streams dynamically to a temporary disk directory. No external proxy libraries are required.
> - **Explicit Offline Mode**: Toggling this in Settings will manually switch the app offline, hiding remote feed elements while keeping local library and downloaded items fully interactive.
> - **YouTube Playlist Sync**: An import input in the Library/Playlist section will pull all songs from a public YouTube playlist directly into a local Drift playlist.

## Proposed Changes

### 1. Stream Caching (media_kit)

#### [MODIFY] [audio_handler.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/features/player/audio_handler.dart)
Configure MPV caching properties during player instantiation/initialization:
- Retrieve a subfolder in the temporary directory (using `path_provider`).
- Cast `_player.platform` to `NativePlayer`.
- Set properties:
  - `cache`: `"yes"`
  - `cache-on-disk`: `"yes"`
  - `cache-dir`: the path to the Sonora cache directory.
  - `demuxer-max-bytes`: `"104857600"` (100 MB cache size limit).
  - `demuxer-max-back-bytes`: `"52428800"` (50 MB back buffer for backward seeking).

---

### 2. Explicit Offline Mode

#### [MODIFY] [settings_provider.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/providers/settings_provider.dart) and [settings_screen_content.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/features/settings/widgets/settings_screen_content.dart) (or similar)
- Add `offlineMode` (boolean, default false) to settings.
- Add a toggle switch in the Settings Screen under the "Connection" or "Privacy" section.

#### [MODIFY] [connectivity_provider.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/providers/connectivity_provider.dart)
Update `isOfflineProvider` to return `true` if either the device is physically offline OR manual `offlineMode` setting is active:
```dart
final isOfflineProvider = Provider<bool>((ref) {
  final manualOffline = ref.watch(settingsProvider).offlineMode;
  if (manualOffline) return true;
  final status = ref.watch(connectivityStatusProvider);
  return status == ConnectivityStatus.isDisconnected;
});
```

#### [MODIFY] [home_mobile_layout.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/features/home/layouts/home_mobile_layout.dart) (and tablet/wide equivalents)
If `isOffline` is active:
- Do not request the YouTube Home Feed (suppress remote API calls).
- Display a clean message stating "Sei in modalità offline. Visualizzazione dei contenuti locali." (You are offline. Showing local content).
- Render only local sections (Your Playlists, Continue Listening, Liked Albums, Followed Artists).

---

### 3. YouTube Playlist Syncing

#### [NEW] [sync_youtube_playlist_use_case.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/domain/usecases/playlist/sync_youtube_playlist_use_case.dart)
Create a use case to sync a playlist:
- Take a YouTube playlist ID or URL.
- Use `youtube_explode_dart` (`yt.playlists.get` & `yt.playlists.getVideos`) to fetch videos.
- Insert a new local playlist in Drift and add all fetched items as entries.

#### [MODIFY] [library_screen.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/features/library/library_screen.dart) (or its layouts/widgets)
Add an "Import Playlist" option next to "Create Playlist" that opens a dialog to paste the YouTube URL and triggers the use case.

---

### 4. Smart Playlists (Auto-mixes)

#### [NEW] [smart_playlists_provider.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/providers/smart_playlists_provider.dart)
Create Riverpod providers for automatic read-only mixes:
- `mostPlayedSongsProvider`: Queries the Drift `history` table, grouped and ordered by playCount descending.
- `recentlyPlayedSongsProvider`: Queries the Drift `history` table, ordered by playedAt descending.
- `forgottenFavoritesProvider`: Queries the Drift `liked_songs` table, cross-referenced with `history` to find liked songs that haven't been played in the last 30 days.

#### [MODIFY] [library_screen.dart](file:///home/gmstyle/VisualStudioCodeProjects/sonora/lib/presentation/features/library/library_screen.dart)
Include a "Smart Mixes" row or tab to let users browse and play these dynamic local playlists.

## Verification Plan

### Automated Tests
- Run `dart analyze` and `flutter test` to ensure compilation and existing tests pass.

### Manual Verification
- **Stream Cache**: Enable cache, stream a song, toggle airplane mode, and verify that playing it again works instantly without internet.
- **Offline Mode**: Turn on "Modalità offline" in settings. Check that home screen hides YTMusic feeds and search disables online results.
- **Playlist Sync**: Paste a public YT Music playlist URL (e.g. `https://music.youtube.com/playlist?list=...`) and verify a new local playlist is populated.
- **Smart Mixes**: Play several songs multiple times. Verify that the "Most Played" and "Recently Played" mixes update instantly.
