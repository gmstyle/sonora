/// Layout constants for the Android TV 10-foot UI.
abstract final class TvMetrics {
  /// Collapsed nav rail when content shelves hold focus (icon-only).
  static const double sidebarCollapsedWidth = 72;

  /// Expanded nav rail when a destination holds focus.
  static const double sidebarExpandedWidth = 220;

  /// Prefer [sidebarCollapsedWidth] / [sidebarExpandedWidth]; kept as the
  /// expanded size for any legacy single-width call sites.
  static const double sidebarWidth = sidebarExpandedWidth;

  static const double navItemHeight = 56;

  /// Poster tile width (~200–220 for 10-foot).
  static const double cardWidth = 220;

  /// Artwork edge; leaves room under the art for title + subtitle in [shelfHeight].
  static const double cardArtSize = 200;

  static const double cardGap = 16;

  /// Circular artist avatars on home shelves.
  static const double artistAvatarSize = 180;

  /// Horizontal shelf viewport (art + labels + focus scale padding).
  static const double shelfHeight = 320;

  /// Shelf height for circular artist rows.
  static const double artistShelfHeight = 280;

  /// Grid cell height for poster cards (search / library).
  static const double cardExtent = 310;

  /// TV overscan safe inset (apply to shelf/content edges).
  static const double overscan = 32;

  static const double horizontalPadding = overscan;
  static const double verticalPadding = 24;

  /// Focus grow; disabled when [Settings.reduceEffects] is on.
  static const double focusScale = 1.12;

  static const double miniPlayerHeight = 96;
  static const double nowPlayingArtSize = 360;

  /// Approximate dock banner stack height when the mini player is hidden.
  static const double dockBannerInset = 72;
}
