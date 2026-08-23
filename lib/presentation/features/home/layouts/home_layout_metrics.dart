import 'package:flutter/material.dart';

enum HomeLayoutSize { mobile, tablet, wide }

class HomeLayoutMetrics {
  final HomeLayoutSize size;

  const HomeLayoutMetrics(this.size);

  factory HomeLayoutMetrics.fromWidth(double width) {
    if (width < 600) return const HomeLayoutMetrics(HomeLayoutSize.mobile);
    if (width < 1200) return const HomeLayoutMetrics(HomeLayoutSize.tablet);
    return const HomeLayoutMetrics(HomeLayoutSize.wide);
  }

  double get horizontalPadding => switch (size) {
    HomeLayoutSize.mobile => 16,
    HomeLayoutSize.tablet => 24,
    HomeLayoutSize.wide => 32,
  };

  double get cardWidth => switch (size) {
    HomeLayoutSize.mobile => 140,
    HomeLayoutSize.tablet => 160,
    HomeLayoutSize.wide => 180,
  };

  /// Space below a square cover for title + artist (matches AlbumCard layout).
  static const double shelfTextHeight = 56;

  /// Fixed height for album/playlist carousel shelves.
  double get carouselShelfHeight => cardWidth + shelfTextHeight;

  /// Height for episode tile shelves (art + title + subtitle).
  static const double episodeShelfHeight = 76;

  /// Width for episode tiles in horizontal shelves.
  double get episodeTileWidth => cardWidth * 2;

  /// Spacing between liked-albums grid cells.
  double get albumGridSpacing => switch (size) {
    HomeLayoutSize.mobile => 8,
    HomeLayoutSize.tablet => 10,
    HomeLayoutSize.wide => 12,
  };

  int get albumGridMinColumns => 3;

  int get albumGridMaxColumns => 6;

  /// Minimum cover width when computing fill-width grid columns on wide.
  double get albumGridMinCellWidth => 140;

  /// Two full rows at max column count (same cap as other home sections).
  int get albumGridMaxItems => 12;

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
