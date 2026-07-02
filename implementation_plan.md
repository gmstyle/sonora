# Implementation Plan - Android Auto Content Alignment

Align the content and sections of Android Auto tabs (Home and Library) with the evolution of the main app.

## Comparative Analysis (App vs Android Auto)

### 1. Home Tab
Currently, the Android Auto Home tab only retrieves and displays sections from the online YouTube Music home feed. The mobile app, however, features a rich combination of both local, personalized, and online feed sections.

| Section | App Home | Current AA Home | Proposed AA Home | Source / Retrieval Method |
| :--- | :---: | :---: | :---: | :--- |
| **YTM Feed Section 0** | Yes | Yes (First 3 items inline) | Yes (First 3 items inline) | `_musicRepo.getHome()` |
| **Your Playlists** | Yes | No | **Yes (Browsable folders)** | Combined local playlists (`_libraryRepo.getAllPlaylists()`) & liked playlists (`_libraryRepo.getAllLikedPlaylists()`) |
| **Your Mixes** | Yes | No | **Yes (Browsable folders)** | Smart mixes (Most Played, Recently Played, Forgotten Favorites) |
| **Continue Listening** | Yes | No | **Yes (Playable songs)** | Recent play history (`_libraryRepo.getRecentHistory(limit: 10)`) |
| **Your Artists** | Yes | No | **Yes (Browsable folders)** | Followed artists (`_libraryRepo.getAllFollowedArtists()`) |
| **Liked Albums** | Yes | No | **Yes (Browsable folders)** | Liked albums (`_libraryRepo.getAllLikedAlbums()`) |
| **New Releases** | Yes | No | **Yes (Browsable folders)** | Releases from followed artists (`GetNewReleasesUseCase`) |
| **Discover** | Yes | No | **Yes (Playable songs)** | Recommendations based on history (`GetDiscoverSuggestionsUseCase`) |
| **Similar Artists** | Yes | No | **Yes (Browsable folders)** | Artists similar to followed ones (`GetSimilarArtistsSuggestionsUseCase`) |
| **YTM Feed Sections 1..N** | Yes | Yes (First 3 items inline) | Yes (First 3 items inline) | `_musicRepo.getHome()` |

*Note: If offline, sections that require internet (like YTM feed, New Releases, Discover, and Similar Artists) will be gracefully skipped, while local sections will remain fully accessible.*

### 2. Library Tab
The app's Library contains six sub-sections/tabs, whereas Android Auto only exposes five of them, omitting the "Mixes" tab.

| Section | App Library | Current AA Library | Proposed AA Library | Source / Retrieval Method |
| :--- | :---: | :---: | :---: | :--- |
| **Favorites** | Yes | Yes | Yes | `_libraryRepo.getAllLikedSongs()` |
| **Artists** | Yes | Yes | Yes | `_libraryRepo.getAllFollowedArtists()` |
| **Playlists** | Yes | Yes | Yes | `_libraryRepo.getAllPlaylists()` |
| **Albums** | Yes | Yes | Yes | `_libraryRepo.getAllLikedAlbums()` |
| **History** | Yes | Yes | Yes | `_libraryRepo.getRecentHistory()` |
| **Mixes** | Yes | No | **Yes (Browsable)** | The 3 smart mixes (Most Played, Recently Played, Forgotten Favorites) |

---

## Proposed Changes

### Background Audio Layer

#### [MODIFY] [audio_handler.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/audio_handler.dart)

1. **Imports**:
   - Add imports for the 3 home use cases:
     - `GetNewReleasesUseCase`
     - `GetDiscoverSuggestionsUseCase`
     - `GetSimilarArtistsSuggestionsUseCase`

2. **Constants**:
   - Define content tree IDs for the new sections:
     - `_yourPlaylistsId = '__your_playlists__'`
     - `_yourMixesId = '__your_mixes__'`
     - `_continueListeningId = '__continue_listening__'`
     - `_yourArtistsId = '__your_artists__'`
     - `_likedAlbumsId = '__liked_albums__'`
     - `_newReleasesId = '__new_releases__'`
     - `_discoverId = '__discover__'`
     - `_similarArtistsId = '__similar_artists__'`
     - `_mixesId = '__mixes__'`
   - Define sub-node IDs for smart mixes:
     - `_smartMixMostPlayedId = '__smart_mix__:most_played'`
     - `_smartMixRecentlyPlayedId = '__smart_mix__:recently_played'`
     - `_smartMixForgottenFavoritesId = '__smart_mix__:forgotten_favorites'`
   - Define action IDs for playing/shuffling smart mixes:
     - `_actionPlaySmartMix = '__action__:play_smart_mix:'`
     - `_actionShuffleSmartMix = '__action__:shuffle_smart_mix:'`

3. **Constructor and Fields**:
   - Add use cases as private fields: `_getNewReleasesUseCase`, `_getDiscoverSuggestionsUseCase`, `_getSimilarArtistsSuggestionsUseCase`.
   - Instantiate them in the constructor.

4. **Mapping Helpers**:
   - Implement `_likedSongToMediaItem(LikedSongModel s)` and `_historyToMediaItem(HistoryModel h)` to map database models to playable `MediaItem`s.

5. **Browse Tree Navigation (`getChildren`)**:
   - **Root Library**: In `_buildLibraryChildren`, add a `_mixesId` ("Mixes") section.
   - **Home Feed**: Rewrite `_buildHomeChildren` to load and interleave both local/use-case sections and online YouTube Music sections. Wrap each section load in an independent try-catch block to handle offline mode or remote failures gracefully.
   - **Switch-case**:
     - Handle `_yourPlaylistsId` to return the combined lists of local and liked playlists.
     - Handle `_yourMixesId` / `_mixesId` to return folders for the 3 smart mixes (Most Played, Recently Played, Forgotten Favorites).
     - Handle `_continueListeningId` to return recent history songs.
     - Handle `_yourArtistsId` to return followed artists.
     - Handle `_likedAlbumsId` to return liked albums.
     - Handle `_newReleasesId` to return new albums.
     - Handle `_discoverId` to return discover recommendations.
     - Handle `_similarArtistsId` to return similar artist browsable folders.
     - Handle `_smartMixMostPlayedId`, `_smartMixRecentlyPlayedId`, `_smartMixForgottenFavoritesId` to return lists of songs belonging to each smart mix (with "Play All" and "Shuffle" action items prepended).

6. **Playback Actions (`playFromMediaId`)**:
   - Handle play/shuffle actions for smart mixes:
     - Fetch the songs of the selected smart mix.
     - Resolve the stream URL of the first song to ensure fast start times and prevent playback failures.
     - Call `playNow`.

---

## Verification Plan

### Automated Tests
- Run code analysis to verify syntactic and type correctness:
  `flutter analyze`

### Manual Verification
- Deploy the app to an emulator or physical device.
- Test using the **Android Auto Desktop Head Unit (DHU)** or Android Auto simulator.
- Verify:
  - **Home tab**: Displays sections in the expected order, with up to 3 items inline.
  - **Library tab**: Shows a new "Mixes" section.
  - **Mixes selection**: Shows the 3 mixes folders (Most Played, Recently Played, Forgotten Favorites).
  - **Mix navigation**: Browsing into a mix shows its tracks and "Play All"/"Shuffle" buttons.
  - **Playback**: Playback triggers correctly when selecting a song, playing all, or shuffling.
  - **Offline resilience**: Turn off Wi-Fi/data, restart the AA connection, and confirm that local sections (Playlists, Mixes, History, etc.) are still visible and browsable.
