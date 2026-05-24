# SONORA — Developer Documentation

> **Versione**: 1.0.0+7 | **Stato**: Release-ready | **Piattaforme**: Android + Linux

---

## 1. Panoramica Architetturale

Sonora è un'app Flutter di audio streaming multi-piattaforma che usa **YouTube Music** come sorgente dati via `dart_ytmusic_api` e `youtube_explode_dart` per la risoluzione degli stream audio.

**Stack principale:**

| Componente | Libreria | Versione |
|---|---|---|
| Framework | Flutter | 3.44.0 (stable) |
| State Management | `flutter_riverpod` | ^3.3.1 |
| Navigazione | `go_router` | ^17.2.3 |
| Database locale | `drift` + `drift_flutter` | ^2.33.0 / ^0.3.0 |
| Audio Playback | `just_audio` + `audio_service` | ^0.10.5 / ^0.18.18 |
| Linux Audio | `just_audio_media_kit` + `media_kit` | ^2.1.0 / ^1.2.6 |
| YTM Data | `dart_ytmusic_api` | git (ramo dev) |
| Stream URL | `youtube_explode_dart` | ^3.1.0 |

**Architettura**: Clean Architecture con 3 layer — `data/`, `domain/`, `presentation/`. I tipi di `dart_ytmusic_api` (`SongDetailed`, `ArtistFull`, ecc.) sono usati direttamente senza mappatura. Le entità locali (liked songs, playlists, ecc.) sono PODO in `domain/models/library_models.dart`.

---

## 2. Struttura del Codice

```
lib/
├── main.dart                          # App bootstrap + ProviderScope overrides
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # kAppVersion, kGitHubRepo*, breakpoints
│   │   └── api_constants.dart         # gl/hl defaults
│   ├── errors/
│   │   └── failures.dart              # sealed class Failure
│   ├── extensions/
│   │   ├── duration_ext.dart           # Duration → "3:45"
│   │   ├── stat_format.dart            # int.toCompact(), stripYtLabel(), nullIfEmpty
│   │   └── string_ext.dart             # String extensions
│   ├── theme/
│   │   └── app_theme.dart              # ThemeData light/dark/amoled + dynamic color
│   └── utils/
│       ├── backup_utils.dart           # JSON serialize/deserialize (no I/O)
│       ├── linux_tray_service.dart     # System tray per Linux
│       ├── notification_utils.dart     # Android foreground notification per download
│       └── platform_utils.dart         # isAndroid, isLinux helpers
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── database.dart           # Drift AppDatabase (schema v9)
│   │   │   ├── database.g.dart         # Generato da build_runner
│   │   │   ├── tables/                 # 10 tabelle Drift
│   │   │   └── daos/                   # 4 DAO (library, playlists, downloads, history)
│   │   └── remote/
│   │       ├── ytmusic_datasource.dart # Wrapper dart_ytmusic_api
│   │       └── stream_datasource.dart  # youtube_explode_dart → stream URL
│   └── repositories/
│       ├── music_repository_impl.dart
│       ├── library_repository_impl.dart
│       └── queue_repository_impl.dart
├── domain/
│   ├── models/
│   │   └── library_models.dart         # 8 PODO (LikedSong, FollowedArtist, ecc.)
│   ├── repositories/
│   │   ├── music_repository.dart
│   │   ├── library_repository.dart
│   │   └── queue_repository.dart
│   └── usecases/
│       ├── player/
│       │   ├── play_video_id_use_case.dart
│       │   ├── play_album_use_case.dart
│       │   ├── play_playlist_use_case.dart
│       │   ├── queue_use_case.dart
│       │   └── start_radio_use_case.dart
│       ├── backup/
│       │   ├── export_backup_use_case.dart
│       │   └── import_backup_use_case.dart
│       ├── download/
│       │   └── start_download_use_case.dart
│       └── update/
│           └── check_for_updates_use_case.dart
├── l10n/
│   ├── app_en.arb                      # Inglese
│   ├── app_it.arb                      # Italiano
│   └── app_localizations_{en,it}.dart   # Generato
└── presentation/
    ├── app/
    │   └── router.dart                  # go_router StatefulShellRoute
    ├── providers/                       # 22 provider Riverpod
    │   ├── player_provider.dart          # PlayerNotifier + PlayerState
    │   ├── settings_provider.dart        # SettingsNotifier (SharedPreferences)
    │   ├── theme_provider.dart           # lightThemeProvider, darkThemeProvider, amoledThemeProvider
    │   ├── library_notifier.dart         # CRUD library
    │   ├── download_provider.dart        # Download progress
    │   ├── update_notifier.dart          # GitHub release check
    │   └── ... (15 DI wiring providers)
    ├── shared/
    │   ├── layouts/                      # app_shell, mobile_shell, tablet_shell, wide_shell
    │   └── widgets/                      # 18 shared widgets (song_tile, artist_card, ecc.)
    └── features/
        ├── home/                         # HomeScreen + 3 layout + HomeSectionRenderer
        ├── search/                       # SearchScreen + SearchProvider
        ├── artist/                       # ArtistScreen + stats row + descrizione
        ├── album/                        # AlbumScreen + AlbumProvider
        ├── playlist/                     # PlaylistScreen + PlaylistProvider
        ├── player/                       # AudioHandler + FullPlayerContent + MiniPlayer
        ├── library/                      # LibraryScreen + 3 layout + PlaylistDetailView
        ├── downloads/                    # DownloadsScreen
        └── settings/                     # SettingsScreen + 3 layout
```

---

## 3. Convenzioni e Regole

### 3.1 Regola del Presentation Layer

Nessun widget chiama mai direttamente `ref.read(*repositoryProvider)`. I percorsi ammessi sono:

1. **Use Case** (`domain/usecases/`) — orchestra ≥2 chiamate a repository/datasource
2. **LibraryNotifier** — CRUD su `LibraryRepository`, singola chiamata al repository
3. **FutureProvider 1:1** — sola lettura (es. `albumProvider → repo.getAlbum()`)

### 3.2 Convenzione Nomi Provider

| Pattern | Uso | Esempio |
|---|---|---|
| `*Provider` | Read-only state o DI wiring | `homeSectionsProvider`, `databaseProvider` |
| `*Notifier` | Mutable state | `SettingsNotifier`, `LibraryNotifier` |
| `*NotifierProvider` | Provider che espone un Notifier | `playerStateProvider`, `settingsProvider` |

### 3.3 Gestione Errori

Il layer domain usa `sealed class Failure` per errori tipizzati. Il layer presentation usa:
- `ErrorRetryWidget` per stati di errore inline
- `SnackBar` per errori contestuali
- `PlayerNotifier.hasError` / `errorMessage` per errori di riproduzione

### 3.4 Formattazione Statistiche

Campi come `playCount`, `viewCount`, `subscriberCount` arrivano dall'API in formati misti:

- **`int` numerici** → `int.toCompact()` (es. 9200000 → "9.2M", 1500 → "1.5K")
- **`String` formattate YTM** → `stripYtLabel()` (es. "51M plays" → "51M", "1.2K views" → "1.2K")
- **`String?` nullable** → `.nullIfEmpty` per convertire stringhe vuote a null

### 3.5 Localizzazione

File ARB in `lib/l10n/`: `app_en.arb` (primario) + `app_it.arb`. Dopo modifica:
```bash
flutter gen-l10n
```

Chiavi aggiunte per le statistiche: `subscribers`, `views`, `description`.

---

## 4. Database Drift — Schema v9

### 4.1 Tabelle

| Tabella | PK | Campi principali | Note |
|---|---|---|---|
| `liked_songs` | videoId | title, artist, thumbnailUrl, artistId, albumId, addedAt | v8: +artistId, albumId |
| `followed_artists` | artistId | name, thumbnailUrl | |
| `liked_albums` | albumId | name, artistName, thumbnailUrl, year, addedAt | v7: nuova |
| `liked_playlists` | playlistId | name, thumbnailUrl, videoCount, addedAt | v7: nuova |
| `local_playlists` | id (auto) | name, description, createdAt | |
| `playlist_entries` | (playlistId, videoId) | position, title, artist, thumbnailUrl | v9: +title, artist, thumbnailUrl |
| `downloads` | videoId | title, artist, thumbnailUrl, localPath, format, fileSize, downloadedAt, status | v5/v6: +title, artist, thumbnailUrl |
| `history` | id (auto) | videoId, title, artist, thumbnailUrl, playedAt, playCount | v4: +thumbnailUrl |
| `search_history` | id (auto) | query, searchedAt | |
| `queue_items` | position (auto) | videoId, title, artist, albumTitle, thumbnailUrl, durationSec, isVideo, streamUrl | v3: +streamUrl |

### 4.2 Generazione Codice

```bash
dart run build_runner build --delete-conflicting-outputs
```

Il file generato è `database.g.dart`. **Ogni modifica alle tabelle** richiede:
1. Incrementare `schemaVersion` in `database.dart`
2. Aggiungere la migrazione in `MigrationStrategy.onUpgrade`
3. Rieseguire `build_runner`

---

## 5. Audio Engine — Dettagli Importanti

### 5.1 `SonoraAudioHandler` (audio_handler.dart)

Estende `BaseAudioHandler` da `audio_service`. È istanziato in `main.dart` e passato sia ad `AudioService.init()` (Android) sia al provider Riverpod.

**Dipendenze iniettate nel costruttore:**
- `MusicRepository` — per risolvere metadati brano
- `LibraryRepository` — per check download locali e like status
- `PlayVideoIdUseCase` — per risoluzione URL + fallback getVideo

**Lazy URL Resolution:**
I Related Items (up-next/auto-play) vengono aggiunti alla coda come **pending** (`extras['needsUrl'] = true`). Quando `currentIndexStream` cambia, `_resolvePendingItems` risolve l'URL per l'item corrente + pre-risolve i 2 successivi. Se l'utente salta, gli URL non necessari non vengono mai risolti.

**Auto-skip su errore:**
Se lo stream URL scade o fallisce, l'handler fa un retry con URL fresco. Se anche il retry fallisce, auto-skip al prossimo brano e notifica via `_onPlayErrorController`.

**Crossfade:**
Implementato via volume fade-in/fade-out nel listener `_handleCrossfade`. Durata configurabile via `Settings.crossfadeSeconds`.

### 5.2 `PlayerNotifier` (player_provider.dart)

Notifier Riverpod con stato immutabile `PlayerState`:

```dart
class PlayerState {
  final bool isPlaying, isLoading, isSwitching, isPaused, hasError;
  final String? errorMessage;
  final MediaItem? currentSong;
  final List<MediaItem> queue;
  final int currentIndex;
  final Duration position, duration;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final Duration? sleepTimerRemaining;
}
```

**Auto-play "Up Next":** Quando `autoPlayUpNext` è attivo e il brano corrente sta per terminare, `PlayerNotifier` prefetcha i brani correlati via `getUpNexts()` e li aggiunge alla coda in background.

### 5.3 MediaItem.extras — Convenzione

Il campo `extras` di `MediaItem` trasporta metadati aggiuntivi:

| Chiave | Tipo | Sorgente | Uso |
|---|---|---|---|
| `url` | String | StreamDatasource / download locale | URL audio per just_audio |
| `videoId` | String | Sempre presente | ID univoco YT |
| `isVideo` | String ("true"/"false") | getVideo fallback | Nasconde tab Lyrics, mostra badge MV |
| `needsUrl` | String ("true") | Lazy resolution | Flag per risoluzione differita |
| `viewCount` | String? | SongFull.viewCount (int→String) | FullPlayerContent stats |
| `publishDate` | String? | SongFull/VideoFull.publishDate | FullPlayerContent stats |
| `musicVideoType` | String? | SongFull/VideoFull.musicVideoType | Badge MV |

---

## 6. Adaptive UI

### 6.1 Breakpoints

```dart
const double kCompactBreakpoint  = 600.0;   // → MobileShell (NavigationBar)
const double kMediumBreakpoint   = 840.0;   // Layout interno (non shell)
const double kExpandedBreakpoint  = 1200.0;  // → WideShell (NavigationDrawer)
```

- 600–1200dp → `TabletShell` (NavigationRail collapsed)
- Ogni feature screen complesso ha layout separati: `*_mobile_layout.dart`, `*_tablet_layout.dart`, `*_wide_layout.dart`

### 6.2 Navigazione

Router: `go_router` con `StatefulShellRoute.indexedStack` in `AppShell`.

| Branch | Path | Screen | Sub-routes |
|---|---|---|---|
| 0 | `/` | HomeScreen | `artist/:artistId`, `album/:albumId`, `playlist/:playlistId` |
| 1 | `/search` | SearchScreen | — |
| 2 | `/library` | LibraryScreen | — |
| 3 | `/downloads` | DownloadsScreen | — |
| 4 | `/settings` | SettingsScreen | — |

Il player è un `DraggableScrollableSheet` che vive **sopra** lo shell — non è una route. Stato: collapsed (72dp mini player) ↔ expanded (full player).

---

## 7. Distribuzione e CI/CD

### 7.1 Release Workflow (`.github/workflows/release.yml`)

**Trigger**: push su `main` + PR su `main`

| Step | Dettaglio |
|---|---|
| Validate | `flutter pub get` → `build_runner` → `flutter analyze` → `flutter test` |
| Version check | Estrae versione da `pubspec.yaml`, salta se tag `v{version}+{build}` esiste già |
| Android build | `flutter build apk --release` con signing da `key.properties` (keystore da GitHub secret `KEYSTORE_BASE64`) |
| Linux build | Installa dipendenze (`clang`, `cmake`, `ninja`, `libgtk-3-dev`, ecc.) → `flutter build linux --release` |
| Linux packaging | `sonora-linux-x64.tar.gz` con `.desktop`, `install.sh`, `uninstall.sh`, icone, tray icon |
| GitHub Release | Tag `v{version}+{build}`, changelog auto-generato, APK + tar.gz allegati |

**Keystore**: PKCS12 convertito a JKS in workflow con `-J-Dkeystore.pkcs12.legacy`.

### 7.2 In-App Update

`UpdateNotifier` + `CheckForUpdatesUseCase` controllano la GitHub Releases API. Su Android, scarica l'APK e lo installa via `open_filex`. Su Linux, apre la pagina release nel browser. Throttle: max 1 check/24h via `SharedPreferences`.

### 7.3 Signing

- **Keystore**: `/home/gmstyle/Documenti/Android_APK_personal_key/APK_personal_gmstyle_key.jks`
- **Alias**: `gmstyle`
- **GitHub Secrets**: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
- **Android config**: `build.gradle.kts` legge da `key.properties`

---

## 8. Campi API Dinamici (Non Persistiti)

Questi campi arrivano dalle API YTMusic e vengono mostrati direttamente nell'UI **senza** essere salvati nel database locale:

### 8.1 Mapping Completo

| Campo | Tipo sorgente | Tipo Dart | Widget | Helper |
|---|---|---|---|---|
| `subscriberCount` | `ArtistFull` / `ArtistDetailed` | `String?` | ArtistScreen stats row | `stripYtLabel()` |
| `monthlyListeners` | `ArtistFull` / `ArtistDetailed` | `String?` | ArtistScreen, ArtistTile, ArtistCard | `stripYtLabel()` |
| `totalViews` | `ArtistFull` | `String?` | ArtistScreen stats row | `stripYtLabel()` |
| `description` | `ArtistFull` | `String?` | ArtistScreen `_ExpandableText` | diretto |
| `playCount` | `SongDetailed` / `VideoDetailed` | `String?` | SongTile, SongCard, ContextMenuSheet, Home, Album | `stripYtLabel()` |
| `viewCount` | `SongFull` (`int?`), `VideoFull`/`VideoDetailed` (`String?`) | misto | FullPlayerContent, ContextMenuSheet | `int.toCompact()` o `stripYtLabel()` |
| `publishDate` | `SongFull` / `VideoFull` | `String?` | FullPlayerContent (sotto artista) | diretto |
| `musicVideoType` | `SongFull` / `VideoFull` | `String?` | MediaItem.extras → badge MV | diretto |

### 8.2 Helper in `stat_format.dart`

```dart
extension CompactNumber on int {
  String toCompact();  // 9200000 → "9.2M", 1500 → "1.5K"
}

String? stripYtLabel(String? value);  // "51M plays" → "51M"
extension StringX on String {
  String? get nullIfEmpty;  // "" → null
}
```

### 8.3 Campi Scartati (Non Usati)

- `channelId` — duplica `artistId`
- `category` — sempre "Music"
- `albumId` su `SongDetailed` — duplica `album?.albumId`
- `uploadDate` — quasi identico a `publishDate`

---

## 9. Android Auto — Content Tree

### 9.1 Struttura a 2 Livelli

```
/ (root)
├── Home
│   ├── [sezioni YTMusic reali] (browsabile)
│   │   ├── Song/Album/Playlist items (playable)
│   │   └── ...
│   └── ...
└── Library
    ├── Liked Songs (playable)
    ├── Artists (browsabile → lista artisti seguiti)
    ├── Playlists (browsabile → playlist locali)
    ├── Albums (browsabile → album liked)
    └── History (playable)
```

### 9.2 Azioni Custom

| Azione | ID | Funzione |
|---|---|---|
| Shuffle | `action_shuffle` | Toggle shuffle mode |
| Repeat | `action_repeat` | Cycle repeat (none → all → one) |
| Like | `action_like` | Toggle liked song |
| Sleep Timer | `action_sleep_timer` | Avvia/ferma timer |
| Play Album | `action_play_album_{id}` | Play da contesto album |
| Shuffle Album | `action_shuffle_album_{id}` | Shuffle album |
| Like Album | `action_like_album_{id}` | Toggle liked album |
| Play Artist | `action_play_artist_{id}` | Artist radio |
| Shuffle Artist | `action_shuffle_artist_{id}` | Shuffle artist |
| Follow Artist | `action_follow_artist_{id}` | Toggle follow |
| Play Playlist | `action_play_playlist_{id}` | Play playlist |
| Shuffle Playlist | `action_shuffle_playlist_{id}` | Shuffle playlist |
| Like Playlist | `action_like_playlist_{id}` | Toggle liked playlist |

### 9.3 Config AudioService

```dart
AudioServiceConfig(
  androidNotificationChannelId: 'com.sonora.music.channel',
  androidNotificationChannelName: 'Sonora',
  androidNotificationOngoing: false,
  androidStopForegroundOnPause: false,
  artDownscaleWidth: 256,
  artDownscaleHeight: 256,
  androidBrowsableRootExtras: {
    'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
    'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
    'android.media.browse.CONTENT_STYLE_SEARCH_SUPPORTED': true,
  },
)
```

---

## 10. Linux Specifico

### 10.1 System Tray

`LinuxTrayService` usa `tray_manager` per:
- Icona tray con stato play/pause
- Menu contestuale: Show, Play/Pause, Next, Previous, Quit
- `window_manager` con `setPreventClose(true)` — chiudi → nasconde a tray

### 10.2 MPRIS

`audio_service_mpris` fornisce integrazione D-Bus MPRIS su Linux. Configurato in `main.dart` insieme ad `audio_service`.

### 10.3 Linux Bundle

Il CI produce `sonora-linux-x64.tar.gz` contenente:
- Binario `sonora`
- `it.gmstyle.sonora.desktop` (desktop entry)
- `sonora.png` (icone)
- `tray_icon.png`
- `install.sh` (copia in `/opt/sonora`, icona, desktop entry)
- `uninstall.sh`

---

## 11. Settings — Preferenze Persistenti

`SettingsNotifier` (backed by `SharedPreferences`) gestisce:

| Key | Tipo | Default | Side-effect |
|---|---|---|---|
| `themeMode` | int (ThemeMode enum) | 0 (system) | ThemeProvider |
| `useDynamicColor` | bool | true | ThemeProvider |
| `useAmoled` | bool | false | ThemeProvider |
| `gl` | String | "US" | YTMusic reinitialize + invalidate home |
| `hl` | String | "en" | YTMusic reinitialize + invalidate home |
| `crossfadeSeconds` | int | 2 | AudioHandler crossfade |
| `restoreQueueOnStartup` | bool | true | QueueUseCase at boot |
| `autoPlayUpNext` | bool | true | PlayerNotifier auto-play |
| `downloadPath` | String? | null | StartDownloadUseCase |
| `downloadOnlyOnWifi` | bool | false | StartDownloadUseCase |
| `trackHistory` | bool | true | AudioHandler history insert |
| `checkUpdatesOnStartup` | bool | true | UpdateNotifier at boot |

---

## 12. Test

### 12.1 File di Test

| File | Conteggio | Copertura |
|---|---|---|
| `test/daos_test.dart` | 65 | Tutti i DAO con upsert, edge case |
| `test/library_repository_test.dart` | 35 | Toggle, mapping, CRUD |
| `test/player_state_test.dart` | 8 | PlayerState + Settings base |
| `test/settings_provider_test.dart` | 20 | Settings model + tutti i 10 setter |

**Totale**: 128 test dichiarati, 93 passano (4 falliscono per bug in `dart_ytmusic_api`: `File('raw.txt')` senza `import 'dart:io'`).

### 12.2 Comandi

```bash
# Analisi statica
flutter analyze

# Test
flutter test

# Generazione codice Drift
dart run build_runner build --delete-conflicting-outputs

# Generazione l10n
flutter gen-l10n
```

---

## 13. Dipendenze Git

`dart_ytmusic_api` è una dipendenza git (non pub.dev):

```yaml
dart_ytmusic_api:
  git:
    url: https://github.com/gmstyle/dart_ytmusic_api.git
```

Per aggiornare:
```bash
flutter pub upgrade dart_ytmusic_api
```

**Bug noto**: il commit attuale ha un riferimento a `File('raw.txt')` senza `import 'dart:io'` che causa il fallimento di 4 test (quelli che importano transitivamente `dart_ytmusic_api`). Non influenza il build dell'app.

---

## 14. Share API

L'app usa `share_plus` v12+ con la nuova API:

```dart
// Pattern corretto (v12+):
await SharePlus.instance.share(ShareParams(text: '...'));

// NON usare la vecchia API:
// Share.share('...');  // DEPRECATA
```

---

## 15. Checklist per Modifiche Comuni

### Aggiungere un campo API dinamico nell'UI

1. Aggiungere il campo al modello `dart_ytmusic_api` (questo nel repo separato)
2. Passare il campo attraverso la catena: `YtmusicDatasource` → `MusicRepositoryImpl` → Use Case/Provider → Widget
3. Se il campo è numerico o ha suffisso YTM, usare `int.toCompact()` o `stripYtLabel()` da `stat_format.dart`
4. Aggiungere chiave l10n in `app_en.arb` + `app_it.arb` → `flutter gen-l10n`

### Aggiungere una tabella Drift

1. Creare il file in `lib/data/datasources/local/tables/`
2. Aggiungere la tabella a `@DriftDatabase(tables: [...])` in `database.dart`
3. Incrementare `schemaVersion`
4. Aggiungere migrazione in `MigrationStrategy.onUpgrade`
5. Aggiungere metodi al DAO appropriato
6. `dart run build_runner build --delete-conflicting-outputs`

### Aggiungere una schermata con layout adattivo

1. Creare `lib/presentation/features/nome_feature/`
2. Creare 3 layout: `*_mobile_layout.dart`, `*_tablet_layout.dart`, `*_wide_layout.dart`
3. Creare lo screen principale che usa `LayoutBuilder` per selezionare il layout
4. Aggiungere la route in `router.dart`
5. Creare il provider se necessario

### Build di release manuale

```bash
# Android
flutter build apk --release --build-name=1.0.0 --build-number=7

# Linux
flutter build linux --release
```

Per il CI/CD, il workflow `release.yml` gestisce tutto automaticamente su push a `main`.