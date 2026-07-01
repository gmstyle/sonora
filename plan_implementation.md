# Piano di consolidamento SongTile

## Obiettivo

Unificare tutti i widget tile per brani/video in un unico `SongTile` esteso, eliminando duplicazioni e garantendo uniformità (es. durata sempre visibile, stesso layout, stessi comportamenti).

---

## Audit iniziale — Discrepanze trovate

### 1. `duration` non passata a SongTile (duration disponibile ma ignorata)

| File | Riga | Modello | Fix |
|------|------|---------|-----|
| `favorites_tab.dart` | 56 | `LikedSongModel` ✅ `int? duration` | Aggiungere `duration: s.duration` |
| `history_tab.dart` | 42 | `HistoryModel` ✅ `int? duration` | Aggiungere `duration: h.duration` |
| `library_search_results_view.dart` | 109 | `LikedSongModel` | Aggiungere `duration: s.duration` |
| `library_search_results_view.dart` | 217 | `HistoryModel` | Aggiungere `duration: h.duration` |

### 2. `duration` non salvata nei siti di inserimento `LikedSongModel`

| Sito | File | Fix |
|------|------|-----|
| `_LikeActionTile` | `context_menu_sheet.dart` | Aggiungere parametro `int? duration` e passarlo a `LikedSongModel` |
| `buildLikeButton` | `player_shared_widgets.dart` | `duration: song.duration?.inSeconds` |
| `_likeButton` | `mini_player_content.dart` | `duration: currentSong.duration?.inSeconds` |
| `setRating` | `audio_handler.dart` | `duration: current?.duration?.inSeconds` |
| `customAction` | `audio_handler.dart` | `duration: item.duration?.inSeconds` |
| `import_backup_use_case.dart` | backup import | `duration: s['duration'] as int?` |

### 3. `isExplicit`/`isVideo` mancanti in backup export/import

| Entità | Campo mancante |
|--------|---------------|
| `likedSongs` export | `isVideo`, `isExplicit` |
| `likedSongs` import | `isVideo`, `isExplicit` |
| `playlistEntries` export | `isVideo`, `isExplicit` |
| `playlistEntries` import | `isVideo`, `isExplicit` |
| `history` export | `duration`, `isExplicit` |
| `history` import | `duration`, `isExplicit` |

---

## Fasi

### ✅ Fase 1 — Fix `duration` mancante (4 call sites)

**File coinvolti:**
- `lib/presentation/features/library/widgets/favorites_tab.dart`
- `lib/presentation/features/library/widgets/history_tab.dart`
- `lib/presentation/features/library/widgets/library_search_results_view.dart` (x2)

**Azione:** Aggiungere `duration:` parameter alla chiamata `SongTile()` in ciascun sito.

**Verifica:** `dart analyze` ok. La durata ora appare nel trailing delle tile in Favorites, History e Library Search.

---

### ✅ Fase 1b — Fix `duration` mancante nei siti di inserimento (6 call sites) + campi mancanti in backup

**File coinvolti:**
- `lib/presentation/shared/widgets/context_menu_sheet.dart`
- `lib/presentation/features/player/widgets/player_shared_widgets.dart`
- `lib/presentation/features/player/mini_player_content.dart`
- `lib/presentation/features/player/audio_handler.dart`
- `lib/domain/usecases/backup/import_backup_use_case.dart`
- `lib/domain/usecases/backup/export_backup_use_case.dart`

**Azione:**
- Aggiungere `duration` a `_LikeActionTile` e passarlo a `LikedSongModel`
- Aggiungere `duration: song.duration?.inSeconds` negli altri 4 siti UI
- Aggiungere `isVideo`, `isExplicit` a likedSongs export/import
- Aggiungere `isVideo`, `isExplicit` a playlistEntries export/import
- Aggiungere `duration`, `isExplicit` a history export/import

**Esclusioni:**
- `downloads`: non inclusi in backup (file fisici non trasferibili)
- `queueItems`: stato effimero, non significativo
- `settings`: già gestiti come raw map pass-through

**Verifica:** `dart analyze` ok.

---

### ✅ Fase 2 — Aggiungere `int? index` a `SongTile` + sostituire `_NumberedSongTile`

**Obiettivo:** Eliminare `_NumberedSongTile` (copia di SongTile + indice) in `artist_screen.dart`.

**Azione:**
- Aggiungere parametro opzionale `int? index` a `SongTile`
- Quando fornito, mostrare il numero traccia (28px) prima della thumbnail nel leading
- Sostituire `_NumberedSongTile` in `artist_screen.dart` con `SongTile(index: i, ...)`
- Rimuovere la classe `_NumberedSongTile` (115+ linee di codice duplicato)

**File coinvolti:**
- `lib/presentation/shared/widgets/song_tile.dart`
- `lib/presentation/features/artist/artist_screen.dart`

---

### ▶️ Fase 3 — Aggiungere `duration` a `PlaylistEntryModel` + database

**Obiettivo:** Abilitare la durata nelle tile delle playlist custom.

**Azione:**
- Aggiungere `int? duration` a `PlaylistEntryModel` in `library_models.dart`
- Aggiungere colonna `IntColumn get duration => integer().nullable()();` in `playlist_entries_table.dart`
- Aggiungere migration se necessario in `database.dart`
- Aggiornare `PlaylistEntryRepository`/DAO per mappare il campo
- Mostrare durata in `_PlaylistEntryTile`

**File coinvolti:**
- `lib/domain/models/library_models.dart`
- `lib/data/datasources/local/tables/playlist_entries_table.dart`
- `lib/data/datasources/local/database.dart`
- `lib/data/repositories/library_repository_impl.dart`
- `lib/presentation/features/library/widgets/playlist_detail_view.dart`

---

### 🔲 Fase 4 — Estendere `SongTile` con `leadingOverride` e `trailingActions` + sostituire `_PlaylistEntryTile`

**Obiettivo:** Usare `SongTile` anche per le tile delle playlist custom, eliminando `_PlaylistEntryTile`.

**Azione:**
- Aggiungere a `SongTile`:
  - `Widget? leadingOverride` — per sostituire il leading (es. drag handle + thumbnail)
  - `List<Widget>? trailingActions` — bottoni extra dopo la durata (es. rimuovi)
- Sostituire `_PlaylistEntryTile` in `playlist_detail_view.dart` con `SongTile`

**File coinvolti:**
- `lib/presentation/shared/widgets/song_tile.dart`
- `lib/presentation/features/library/widgets/playlist_detail_view.dart`

---

## Riepilogo file modificati

| Fase | File | Tipo modifica |
|------|------|--------------|
| 1 | `favorites_tab.dart` | +1 riga `duration:` |
| 1 | `history_tab.dart` | +1 riga `duration:` |
| 1 | `library_search_results_view.dart` | +2 righe `duration:` |
| 1b | `context_menu_sheet.dart` | +parametro `duration` classe/costruttore/call site/LikedSongModel |
| 1b | `player_shared_widgets.dart` | +1 riga `duration:` |
| 1b | `mini_player_content.dart` | +1 riga `duration:` |
| 1b | `audio_handler.dart` | +2 righe `duration:` (setRating + customAction) |
| 1b | `export_backup_use_case.dart` | + `isVideo, isExplicit, duration` in likedSongs, playlistEntries, history |
| 1b | `import_backup_use_case.dart` | + `isVideo, isExplicit, duration` in likedSongs, playlistEntries, history |
| 2 | `song_tile.dart` | +parametro opzionale `int? index` |
| 2 | `artist_screen.dart` | Sostituire `_NumberedSongTile` con `SongTile`, rimuovere classe |
| 3 | `library_models.dart` | + `int? duration` in `PlaylistEntryModel` |
| 3 | `playlist_entries_table.dart` | + colonna `duration` |
| 3 | `database.dart` | + migration per nuova colonna |
| 3 | `library_repository_impl.dart` | + mapping `duration` |
| 3 | `playlist_detail_view.dart` | Mostrare durata in `_PlaylistEntryTile` |
| 4 | `song_tile.dart` | + `leadingOverride`, `trailingActions` |
| 4 | `playlist_detail_view.dart` | Sostituire `_PlaylistEntryTile` con `SongTile` |
