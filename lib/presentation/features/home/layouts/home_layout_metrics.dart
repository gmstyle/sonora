import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/feed_grid.dart';

enum HomeLayoutSize { mobile, tablet, wide }

class HomeLayoutMetrics {
  final HomeLayoutSize size;

  /// Width of the home content box. Zero when the caller only knows [size].
  final double contentWidth;

  const HomeLayoutMetrics(this.size, {this.contentWidth = 0});

  /// Picks mobile / tablet / wide metrics.
  ///
  /// When [shortestSide] indicates a compact shell (phone, including
  /// landscape), always returns [HomeLayoutSize.mobile] even if [width]
  /// is ≥ 600.
  factory HomeLayoutMetrics.fromWidth(double width, {double? shortestSide}) {
    if (shortestSide != null && shortestSide < kCompactBreakpoint) {
      return HomeLayoutMetrics(HomeLayoutSize.mobile, contentWidth: width);
    }
    if (width < kCompactBreakpoint) {
      return HomeLayoutMetrics(HomeLayoutSize.mobile, contentWidth: width);
    }
    if (width < kExpandedBreakpoint) {
      return HomeLayoutMetrics(HomeLayoutSize.tablet, contentWidth: width);
    }
    return HomeLayoutMetrics(HomeLayoutSize.wide, contentWidth: width);
  }

  double get horizontalPadding => switch (size) {
    HomeLayoutSize.mobile => kCompactContentPadding,
    HomeLayoutSize.tablet => 24,
    HomeLayoutSize.wide => kWideContentPadding,
  };

  /// Shelf card width.
  ///
  /// Compact and tablet stay on the 140 / 160 scale. Wide cards use the same
  /// width as a fill-width feed grid cell (4 / 5 / 6 columns) so carousels
  /// match the liked-albums grid. Carousels keep their 8px gap, so the next
  /// card peeks.
  double get cardWidth {
    if (size == HomeLayoutSize.mobile) return 140;
    if (size == HomeLayoutSize.tablet) return 160;
    if (contentWidth < kExpandedBreakpoint) return 180;
    final columns = feedGridColumnCount(contentWidth);
    final fitted = feedGridCardWidth(
      contentWidth,
      columns: columns,
      horizontalPadding: horizontalPadding,
      crossAxisSpacing: albumGridSpacing,
    );
    if (fitted <= 0) return 180;
    return fitted;
  }

  /// Space below a square cover for title + artist (matches AlbumCard layout).
  static const double shelfTextHeight = 56;

  /// Fixed height for album/playlist carousel shelves.
  double get carouselShelfHeight => cardWidth + shelfTextHeight;

  /// Height for episode tile shelves (art + title + subtitle).
  static const double episodeShelfHeight = 76;

  /// Width for episode tiles in horizontal shelves.
  ///
  /// Square covers follow the feed column scale on wide. Episode rows stay
  /// at the previous wide tile so a 76px shelf does not stretch with them.
  double get episodeTileWidth =>
      size == HomeLayoutSize.wide ? 360 : cardWidth * 2;

  /// Spacing between liked-albums grid cells.
  double get albumGridSpacing => switch (size) {
    HomeLayoutSize.mobile => 8,
    HomeLayoutSize.tablet => 10,
    HomeLayoutSize.wide => 12,
  };

  /// Fill-width columns for the wide liked-albums grid.
  ///
  /// 4 at ≥1200, 5 at ≥1600, 6 at ≥1920, from [contentWidth].
  int get albumGridColumns {
    final width = contentWidth >= kExpandedBreakpoint
        ? contentWidth
        : kExpandedBreakpoint;
    return feedGridColumnCount(width);
  }

  /// Two full rows at the active column count.
  int get albumGridMaxItems => albumGridColumns * 2;

  double get artistAvatarSize => size == HomeLayoutSize.wide ? 72 : 64;

  double get continueThumbnailSize => size == HomeLayoutSize.mobile ? 48 : 56;

  double get heroHeight => switch (size) {
    HomeLayoutSize.mobile => 160,
    HomeLayoutSize.tablet => 180,
    HomeLayoutSize.wide => 200,
  };

  double get heroViewportFraction => switch (size) {
    HomeLayoutSize.mobile => 0.9,
    HomeLayoutSize.tablet => 0.7,
    HomeLayoutSize.wide => 0.55,
  };

  double get zoneHeaderTop => switch (size) {
    HomeLayoutSize.mobile => 24,
    HomeLayoutSize.tablet => 28,
    HomeLayoutSize.wide => 32,
  };

  double get zoneHeaderBottom => switch (size) {
    HomeLayoutSize.mobile => 8,
    HomeLayoutSize.tablet => 12,
    HomeLayoutSize.wide => 16,
  };

  double get zoneGap => switch (size) {
    HomeLayoutSize.mobile => 16,
    HomeLayoutSize.tablet => 20,
    HomeLayoutSize.wide => 24,
  };

  double get quickRowPadding => horizontalPadding;

  EdgeInsets get sectionPadding => EdgeInsets.fromLTRB(
    horizontalPadding,
    zoneGap,
    horizontalPadding,
    zoneHeaderBottom,
  );

  bool get isWide => size == HomeLayoutSize.wide;

  bool get isMobile => size == HomeLayoutSize.mobile;

  bool get useSideBySideArtists => isWide;

  bool get useLikedAlbumsGrid => isWide;

  bool get useSideBySideQuickRow => !isMobile;
}
