import 'dart:ui' show Size;

import '../constants/app_constants.dart';

/// Whether [AppShell] would pick [MobileShell] for this window size.
///
/// Compact is `shortestSide < kCompactBreakpoint`, so landscape phones stay
/// on mobile family layouts even when width is ≥ 600.
bool isCompactShell(Size size) => size.shortestSide < kCompactBreakpoint;

/// Whether [AppShell] would pick [TabletShell] for this window size.
bool isTabletShell(Size size) =>
    !isCompactShell(size) && size.width < kExpandedBreakpoint;

/// Whether [AppShell] would pick [WideShell] for this window size.
bool isWideShell(Size size) =>
    !isCompactShell(size) && size.width >= kExpandedBreakpoint;
