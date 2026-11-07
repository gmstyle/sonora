import '../constants/app_constants.dart';

/// Content width where feed grids step from five columns to six.
/// Not a shell breakpoint.
const double _kFeedSixColumnWidth = 1920;

/// Column count for feed shelves and fill-width grids.
///
/// Compact content is 2. From [kCompactBreakpoint] until
/// [kFeedFourColumnContentWidth] the count is 3. Four columns run from
/// there until [kWideContentBreakpoint]. Five columns start at 1600, six
/// at 1920. Pass the content box width, not the window width.
int feedGridColumnCount(double contentWidth) {
  if (!contentWidth.isFinite || contentWidth < kCompactBreakpoint) return 2;
  if (contentWidth >= _kFeedSixColumnWidth) return 6;
  if (contentWidth >= kWideContentBreakpoint) return 5;
  if (contentWidth < kFeedFourColumnContentWidth) return 3;
  return 4;
}

/// Horizontal padding for explore feed pages.
///
/// Wide content (≥ [kExpandedBreakpoint]) uses [kWideContentPadding].
/// Tablet content (≥ [kCompactBreakpoint]) uses [kTabletContentPadding].
/// Compact pages keep 16. Home keeps its own 16 / 24 / 32 scale instead
/// of this helper.
double feedHorizontalPadding(double contentWidth) {
  if (!contentWidth.isFinite) return 16;
  if (contentWidth >= kExpandedBreakpoint) return kWideContentPadding;
  if (contentWidth >= kCompactBreakpoint) return kTabletContentPadding;
  return 16;
}

/// Width of one grid cell that fills [contentWidth] after padding and gaps.
double feedGridCardWidth(
  double contentWidth, {
  required int columns,
  double horizontalPadding = 16,
  double crossAxisSpacing = 12,
}) {
  if (!contentWidth.isFinite || columns <= 0) return 0;
  final gaps = (columns - 1) * crossAxisSpacing;
  final inner = contentWidth - horizontalPadding * 2 - gaps;
  if (inner <= 0) return 0;
  return inner / columns;
}

/// Column count, padding, and cell width for one explore feed grid.
class FeedGridSpec {
  final int columns;
  final double horizontalPadding;
  final double cardWidth;

  const FeedGridSpec({
    required this.columns,
    required this.horizontalPadding,
    required this.cardWidth,
  });

  factory FeedGridSpec.fromWidth(
    double contentWidth, {
    double crossAxisSpacing = 12,
  }) {
    final columns = feedGridColumnCount(contentWidth);
    final horizontalPadding = feedHorizontalPadding(contentWidth);
    return FeedGridSpec(
      columns: columns,
      horizontalPadding: horizontalPadding,
      cardWidth: feedGridCardWidth(
        contentWidth,
        columns: columns,
        horizontalPadding: horizontalPadding,
        crossAxisSpacing: crossAxisSpacing,
      ),
    );
  }
}
