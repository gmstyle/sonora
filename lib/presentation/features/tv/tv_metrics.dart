/// Android TV layout tokens — standalone 10-foot product surface.
///
/// Design canvas is Material TV MDPI **960×540** (1px = 1dp). Sonora STBs with
/// density 320 on a 1080p override expose that logical size; tokens are authored
/// for it. Brand stays Pulse; anatomy follows Material TV / Leanback canons
/// (browser rows, left nav overlay, overscan), **not** phone shells or JetFit.
///
/// Spec: https://developer.android.com/design/ui/tv/guides/styles/layouts
abstract final class TvMetrics {
  static const double designWidth = 960;
  static const double designHeight = 540;

  /// Overscan-safe inset from screen edges (~5%).
  static const double overscanHorizontal = 48;
  static const double overscanVertical = 27;

  /// Collapsed left nav (icons). Content reserves this gutter always.
  static const double railCollapsedWidth = 72;

  /// Expanded left nav overlay (labels). Does not resize the content pane.
  static const double railExpandedWidth = 240;

  static const double railIconSize = 28;

  /// Padding inside the content pane (right edge ≈ overscan; left after rail).
  static const double contentPadding = 40;

  /// Browser-template shelf (vertical stack of horizontal rows).
  static const double shelfGap = 28;
  static const double shelfTitleGap = 12;

  /// Standard catalog poster (~5 cards across usable width).
  static const double shelfCardWidth = 148;
  static const double shelfCardHeight = 148;
  static const double shelfCardTextHeight = 44;
  static const double shelfRowHeight =
      shelfCardHeight + shelfCardTextHeight + 20;

  /// Featured / hero items as a **row** of landscape cards (not a full-bleed
  /// marketing panel). 16:9-ish for 10-foot browsing.
  static const double featuredCardWidth = 268;
  static const double featuredCardHeight = 150;
  static const double featuredRowHeight = featuredCardHeight + 36;

  /// Mood / genre landscape chips.
  static const double categoryCardWidth = 220;
  static const double categoryCardHeight = 100;
  static const double categoryRowHeight = categoryCardHeight + 36;

  static const double focusScale = 1.1;
  static const double cardRadius = 12;

  /// Thin media controls strip. Music ATV apps keep this; it must not rival
  /// the browse rows (≈7% of design height).
  static const double dockHeight = 40;
  static const double dockArtSize = 28;
  static const double dockIconSize = 18;

  static const Duration drawerAnimDuration = Duration(milliseconds: 200);

  /// Immersive entity header — under half the viewport so the track list peeks.
  static const double entityHeaderFraction = 0.40;

  /// Top padding for the first browse row (overscan-aware).
  static const double browseTopPadding = 24;
}
