import '../constants/app_constants.dart';

/// Content width where feed grids step from five columns to six.
/// Not a shell breakpoint.
const double _kFeedSixColumnWidth = 1920;

bool _isCompactShellShortest(double? shellShortestSide) =>
    shellShortestSide != null && shellShortestSide < kCompactBreakpoint;

/// Column count for feed shelves and fill-width grids.
///
/// Compact content is 2. From [kCompactBreakpoint] until
/// [kFeedFourColumnContentWidth] the count is 3. Four columns run from
/// there until [kWideContentBreakpoint]. Five columns start at 1600, six
/// at 1920. Pass the content box width, not the window width.
///
/// When [shellShortestSide] indicates a compact shell (phone, including
/// landscape), always return 2 columns even if [contentWidth] is ≥ 600.
int feedGridColumnCount(double contentWidth, {double? shellShortestSide}) {
  if (_isCompactShellShortest(shellShortestSide)) return 2;
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
/// Compact pages keep [kCompactContentPadding]. Home keeps its own
/// 16 / 24 / 32 scale instead of this helper.
///
/// When [shellShortestSide] indicates a compact shell, always return
/// [kCompactContentPadding] even if [contentWidth] is ≥ 600.
double feedHorizontalPadding(double contentWidth, {double? shellShortestSide}) {
  if (_isCompactShellShortest(shellShortestSide)) {
    return kCompactContentPadding;
  }
  if (!contentWidth.isFinite) return kCompactContentPadding;
  if (contentWidth >= kExpandedBreakpoint) return kWideContentPadding;
  if (contentWidth >= kCompactBreakpoint) return kTabletContentPadding;
  return kCompactContentPadding;
}

/// Width of one grid cell that fills [contentWidth] after padding and gaps.
double feedGridCardWidth(
  double contentWidth, {
  required int columns,
  double horizontalPadding = kCompactContentPadding,
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
    double? shellShortestSide,
  }) {
    final columns = feedGridColumnCount(
      contentWidth,
      shellShortestSide: shellShortestSide,
    );
    final horizontalPadding = feedHorizontalPadding(
      contentWidth,
      shellShortestSide: shellShortestSide,
    );
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
