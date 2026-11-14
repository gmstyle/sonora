/// 10-foot layout tokens for [TvShell] and TV screens.
///
/// Kept separate from phone/tablet breakpoints: TV is a device shell, not a
/// width tier. Anatomy follows JetFit (80↔220 drawer); brand tokens stay Pulse.
abstract final class TvMetrics {
  /// Collapsed navigation drawer width (icons only).
  static const double railCollapsedWidth = 80;

  /// Expanded navigation drawer width (icons + labels).
  static const double railExpandedWidth = 220;

  static const double railIconSize = 28;
  static const double contentPadding = 48;
  static const double shelfGap = 24;
  static const double shelfCardWidth = 200;
  static const double shelfCardHeight = 200;

  /// Vertical room for title + subtitle under the poster cover.
  static const double shelfCardTextHeight = 64;

  /// Horizontal list viewport (cover + text + focus ring / scale slack).
  static const double shelfRowHeight =
      shelfCardHeight + shelfCardTextHeight + 40;

  static const double shelfTitleGap = 12;
  static const double heroHeight = 360;
  static const double focusScale = 1.08;
  static const double cardRadius = 16;
  static const double dockHeight = 104;
  static const Duration drawerAnimDuration = Duration(milliseconds: 200);
}
