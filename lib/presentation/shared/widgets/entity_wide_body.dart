import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';

/// Horizontal inset for an entity page.
///
/// Compact content (< [kCompactBreakpoint]) is [kCompactContentPadding].
/// Tablet content is [kTabletContentPadding]. Wide content
/// (≥ [kExpandedBreakpoint]) is [kWideContentPadding]. Pass the content
/// box width, not the window.
///
/// When [shellShortestSide] indicates a compact shell (phone, including
/// landscape), always return [kCompactContentPadding] even if
/// [contentWidth] is ≥ 600.
double entityHorizontalPadding(
  double contentWidth, {
  double? shellShortestSide,
}) {
  if (shellShortestSide != null && shellShortestSide < kCompactBreakpoint) {
    return kCompactContentPadding;
  }
  if (!contentWidth.isFinite || contentWidth < kCompactBreakpoint) {
    return kCompactContentPadding;
  }
  if (contentWidth < kExpandedBreakpoint) return kTabletContentPadding;
  return kWideContentPadding;
}

/// Body padding under an entity header. Wide keeps the dock clearance (48).
EdgeInsets entityBodyPadding(
  double contentWidth, {
  double top = 16,
  double? shellShortestSide,
}) {
  final horizontal = entityHorizontalPadding(
    contentWidth,
    shellShortestSide: shellShortestSide,
  );
  final compact =
      shellShortestSide != null && shellShortestSide < kCompactBreakpoint;
  final wide = !compact && contentWidth >= kExpandedBreakpoint;
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    wide ? 48 : kCompactContentPadding,
  );
}

/// Track or episode column for entity screens.
///
/// Header and actions stay outside this widget so they span the full content
/// width. [about], [list], and [related] stack in one full-width column.
class EntityWideBody extends StatelessWidget {
  final Widget list;
  final Widget? about;
  final Widget? related;

  const EntityWideBody({
    super.key,
    required this.list,
    this.about,
    this.related,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (about != null) ...[about!, const SizedBox(height: 16)],
        list,
        if (related != null) ...[const SizedBox(height: 24), related!],
      ],
    );
  }
}
