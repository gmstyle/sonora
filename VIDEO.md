# Piano: Supporto Video in Sonora

## Premesse tecniche

- `media_kit` v1.2.6 già installato (backend audio via `just_audio_media_kit`)
- **Da aggiungere**: `media_kit_video` v2.0.1 (widget `Video` + `VideoController`)
- `just_audio` resta il player audio primario (audio_service, Android Auto, MPRIS)
- Il video player `media_kit` è un player **secondario, mutato**, che renderizza solo il video
- Nessun conflitto: `media_kit` supporta istanze `Player` multiple

## Architettura

```
┌─────────────────────┐
│  just_audio Player   │ ← Audio primario (audio_service)
│  (SonoraAudioHandler)│
└─────────┬───────────┘
          │ positionStream, playbackState, mediaItem
          ▼
┌─────────────────────┐
│  PlayerNotifier      │ ← Riverpod state
│  (playerStateProvider)│
└─────────┬───────────┘
          │ watch
          ▼
┌─────────────────────┐
│ VideoPlayerNotifier  │ ← Nuovo provider
│ (videoPlayerProvider)│
│                      │
│  media_kit Player    │ ← Video secondario (muted)
│  (VideoController)   │
└─────────────────────┘
```

## Step 1: Aggiungere dipendenza `media_kit_video`

**File**: `pubspec.yaml`

Aggiungere sotto le dipendenze media_kit esistenti:

```yaml
media_kit_video: ^2.0.1
```

## Step 2: Creare il Video Player Provider

**File nuovo**: `lib/presentation/providers/video_player_provider.dart`

Responsabilità:
- Creare un `media_kit.Player` singleton (con `muted: true` per evitare doppio audio)
- Creare un `VideoController` associato
- Esporre stato: `isVideoActive` (deriva da `currentSong.extras['isVideo']`), `isVideoVisible` (toggle utente, default `true`)
- Sincronizzazione con `playerStateProvider`:
  - Quando `isPlaying` cambia → video player play/pause
  - Quando cambia traccia → caricare nuovo URL video o nascondere video
  - Quando `position` diverge significativamente dal video → seek video
- Il provider si disfa del `Player` quando non necessario

Logica chiave:
```
currentSong cambia?
  ├── isVideo == true → carica URL muxed nel video player, mostra video
  └── isVideo == false → stop video player, nascondi video
```

## Step 3: Creare il Video Player Widget

**File nuovo**: `lib/presentation/features/player/widgets/video_player_widget.dart`

Responsabilità:
- Widget riutilizzabile che wrappa `media_kit_video.Video`
- Riceve il `VideoController` dal provider
- Supporta parametri: `fit` (BoxFit.cover), `aspectRatio` (16:9 per video), `borderRadius`
- Quando non c'è video o è disattivato, mostra un fallback (artwork statico)

## Step 4: Modificare il Full Player

**File**: `lib/presentation/features/player/full_player_content.dart`

Modifiche:
- Nell'area `_artwork()` (3 layout: mobile/tablet/wide), quando `isVideo == true` E `isVideoVisible == true`:
  - Sostituire l'immagine statica con il `VideoPlayerWidget`
  - Il video si adatta allo spazio dell'artwork (stesse dimensioni, aspect ratio 16:9 anziché 1:1)
- Aggiungere **toggle video** in `_bottomActionsRow()` (accanto al bottone lyrics):
  - Icona: `LucideIcons.monitor` quando video attivo, `LucideIcons.monitorOff` quando disattivato
  - Visibile solo quando `isVideo == true`
  - Toggle: chiama `videoPlayerNotifier.toggleVisibility()`
  - Quando disattivato: mostra artwork statico, audio continua senza interruzione

## Step 5: Modificare il Mini Player Mobile

**File**: `lib/presentation/features/player/player_sheet_mobile.dart`

Modifiche:
- Nel widget `_MiniArtwork` (44x44): quando `isVideo == true` E `isVideoVisible == true`, mostrare il `VideoPlayerWidget` al posto dell'immagine
- Il video nel mini player è un piccolo viewport (stesse dimensioni dell'artwork: 44x44 su mobile)
- Quando l'utente apre il full player, il video continua a riprodursi (stessa istanza del player)

## Step 6: Modificare il Mini Player Tablet/Wide

**File**: `lib/presentation/features/player/mini_player_content.dart`

Modifiche:
- Nel metodo `_artwork()` (condiviso da tablet e desktop): quando `isVideo == true` E `isVideoVisible == true`, mostrare il `VideoPlayerWidget`
- Stesse dimensioni dell'artwork attuale (56-60px tablet, 56px desktop)

## Step 7: Aggiornare Player State

**File**: `lib/presentation/providers/player_provider.dart`

Aggiungere un getter in `PlayerState`:

```dart
bool get isVideo => currentSong?.extras?['isVideo'] == true;
```

Questo evita di calcolare `isVideo` ripetutamente nei widget.

## Sincronizzazione Video-Audio

1. `VideoPlayerNotifier` ascolta `playerStateProvider` via `ref.listen`
2. Su cambio `isPlaying` → `videoPlayer.play()` o `videoPlayer.pause()`
3. Su cambio `currentSong` → se `isVideo`, apre nuovo `Media(url)` nel video player
4. Su cambio traccia → seek video a `Duration.zero` per allinearsi
5. Posizione: il video player si autocollega all'audio (stesso URL muxed), quindi la sincronizzazione è naturale. Solo in caso di drift significativo (>500ms) si fa un `seek` correttivo.

## File da creare/modificare

| # | File | Azione |
|---|---|---|
| 1 | `pubspec.yaml` | Aggiungere `media_kit_video: ^2.0.1` |
| 2 | `lib/presentation/providers/video_player_provider.dart` | **NUOVO** - Provider video player |
| 3 | `lib/presentation/features/player/widgets/video_player_widget.dart` | **NUOVO** - Widget video |
| 4 | `lib/presentation/features/player/full_player_content.dart` | Video area + toggle |
| 5 | `lib/presentation/features/player/player_sheet_mobile.dart` | Video nel mini player mobile |
| 6 | `lib/presentation/features/player/mini_player_content.dart` | Video nel mini player tablet/desktop |
| 7 | `lib/presentation/features/player/widgets/player_shared_widgets.dart` | Toggle video in bottom actions |
| 8 | `lib/presentation/providers/player_provider.dart` | Getter `isVideo` |

## Nota su `media_kit` e `just_audio_media_kit`

Poiché `just_audio_media_kit` usa internamente `media_kit` come engine audio, creare un secondo `Player` per il video non causa conflitti. Il video player sarà:
- **Muted** (volume 0) per evitare doppio audio
- **Usato solo per il rendering video** (il frame buffer)
- **Sincronizzato** con l'audio player principale
