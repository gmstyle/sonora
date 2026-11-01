/// Layout constants for the Android TV 10-foot UI.
abstract final class TvMetrics {
  static const double sidebarWidth = 280;
  static const double navItemHeight = 56;
  static const double cardWidth = 200;

  /// Artwork edge; leaves room under the art for title + subtitle in [shelfHeight].
  static const double cardArtSize = 180;
  static const double cardGap = 16;

  /// Horizontal shelf viewport (art + labels + focus scale padding).
  static const double shelfHeight = 300;

  /// Grid cell height for poster cards (search / library).
  static const double cardExtent = 292;
  static const double horizontalPadding = 32;
  static const double verticalPadding = 24;
  static const double focusScale = 1.08;
  static const double miniPlayerHeight = 96;
  static const double nowPlayingArtSize = 360;
}
