# Landscape Player Adjustments and Auto-Fullscreen

This plan outlines the changes needed to improve the user experience of the full player on mobile/tablet devices in landscape mode.

## Proposed Changes

We will modify five files:
1. `full_player_content.dart` to improve landscape mobile detection and introduce a persistent `GlobalKey` for the artwork widget to preserve video player state when reparented.
2. `video_player_widget.dart` to support auto-entering and auto-exiting fullscreen on orientation changes for mobile and tablet devices.
3. `artwork.dart` to pass the `autoFullscreenOnLandscape` flag to `SonoraVideoPlayer`.
4. `player_bouncing_widget.dart` to hide the "Up Next" card in the player's default view when the vertical space is tight (landscape mobile).
5. The three player layouts (`mobile_player_layout.dart`, `tablet_player_layout.dart`, `wide_player_layout.dart`) to accept and pass the persistent `artworkKey` to the `Artwork` widget.

---

### Component: Presentation Features - Player Layouts & Widgets

#### [MODIFY] [full_player_content.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/full_player_content.dart)

- Define `isLandscapeMobile` checking both width (< `kCompactBreakpoint`) and height (< `kCompactBreakpoint`). This correctly identifies phones in landscape mode, as their height is always < 600px, while tablets have height >= 600px.
- Declare a persistent `final GlobalKey _artworkKey = GlobalKey(debugLabel: 'player_artwork');` in the state to allow reparenting the artwork widget without recreation.
- Pass `artworkKey: _artworkKey` to `MobilePlayerLayout`, `TabletPlayerLayout`, and `WidePlayerLayout`.

#### [MODIFY] [video_player_widget.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/widgets/video_player_widget.dart)

- Add a `final bool autoFullscreenOnLandscape` parameter to `SonoraVideoPlayer` (defaulting to `false`).
- Import `dart:io` to check if we are on Android/iOS (`Platform.isAndroid || Platform.isIOS`).
- Use `didChangeDependencies` to observe orientation changes. When `autoFullscreenOnLandscape` and platform is Android/iOS:
  - If orientation changes to `Orientation.landscape`, call `_videoKey.currentState?.enterFullscreen()`.
  - If orientation changes to `Orientation.portrait`, call `_videoKey.currentState?.exitFullscreen()` (if currently fullscreen).

#### [MODIFY] [artwork.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/widgets/artwork.dart)

- Pass `autoFullscreenOnLandscape: true` to the `SonoraVideoPlayer` inside the `build` method.

#### [MODIFY] [player_bouncing_widget.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/widgets/player_bouncing_widget.dart)

- In `PlayerDefaultView`, hide the `Up Next` card when `widget.tight` is `true`. This avoids layout overlap/crowding in the right column of the landscape player, keeping only the beautiful audio visualizer (and the sleep timer badge if active).

#### [MODIFY] [mobile_player_layout.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/layouts/mobile_player_layout.dart)
#### [MODIFY] [tablet_player_layout.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/layouts/tablet_player_layout.dart)
#### [MODIFY] [wide_player_layout.dart](file:///Users/gabriele.martina/Documents/AndroidStudioProjects/sonora/lib/presentation/features/player/layouts/wide_player_layout.dart)

- Accept `artworkKey` in constructors.
- Pass `key: widget.artworkKey` (or `key: artworkKey`) to the child `Artwork` widget instantiation.

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure there are no regressions or compilation errors in existing tests.

### Manual Verification
- Run the app on a simulator or device.
- Open the full player with an audio song:
  - Verify layout in portrait mode.
  - Rotate the device to landscape. Verify that the artwork is on the left and the right column fits perfectly without overflow or overlapping widgets (visualizer and sleep timer should be centered in the remaining height of the right column, while the "Up Next" card is hidden).
  - Open lyrics/queue in landscape. Verify it shows in `FullscreenOverlayLayout` taking up the full width/height (instead of the cramped split layout).
- Open the full player with a video:
  - Verify layout in portrait.
  - Rotate the device to landscape. Verify that it automatically enters full-screen mode.
  - Rotate the device back to portrait. Verify that it automatically exits full-screen mode.
