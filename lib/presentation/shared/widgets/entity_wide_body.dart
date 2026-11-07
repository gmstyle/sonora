import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';

/// Horizontal inset for an entity page.
///
/// Compact content (< [kCompactBreakpoint]) is 16. Tablet content is
/// [kTabletContentPadding]. Wide content (≥ [kExpandedBreakpoint]) is
/// [kWideContentPadding]. Pass the content box width, not the window.
double entityHorizontalPadding(double contentWidth) {
  if (!contentWidth.isFinite || contentWidth < kCompactBreakpoint) return 16;
  if (contentWidth < kExpandedBreakpoint) return kTabletContentPadding;
  return kWideContentPadding;
}

/// Body padding under an entity header. Wide keeps the dock clearance (48).
EdgeInsets entityBodyPadding(double contentWidth, {double top = 16}) {
  final horizontal = entityHorizontalPadding(contentWidth);
  final wide = contentWidth >= kExpandedBreakpoint;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, wide ? 48 : 16);
}

/// Track or episode column for entity screens.
///
/// Header and actions stay outside this widget so they span the full content
/// width. When [wide] is false the children stack in the order compact and
/// tablet already use. When [wide] is true, [list] caps at
/// [kEntityTrackMaxWidth] if the related rail is hidden. At
/// [kWideContentBreakpoint] the existing about / related blocks move into a
/// [kEntityRelatedRailWidth] rail and [list] takes the remaining width.
///
/// [related] is the block that sits under the list (carousels). [relatedRail]
/// is that same data stacked for the narrow column. No new fetches.
class EntityWideBody extends StatelessWidget {
  final Widget list;
  final Widget? about;
  final Widget? related;
  final Widget? relatedRail;

  /// Shell wide layout. Compact and tablet pass false.
  final bool wide;

  /// When false, [list] is not capped (a shelf, not a track column).
  final bool capList;

  const EntityWideBody({
    super.key,
    required this.list,
    this.about,
    this.related,
    this.relatedRail,
    this.wide = false,
    this.capList = true,
  });

  /// Minimum list width beside the rail. Narrower panes keep the stack.
  static const double minListBesideRail = 480;

  /// True when [contentWidth] can hold the related rail.
  ///
  /// [contentWidth] is the padded entity body, not the window. The window
  /// still has to reach [kWideContentBreakpoint].
  static bool showRelatedRail(
    BuildContext context,
    double contentWidth, {
    required bool hasRelated,
  }) {
    if (!hasRelated) return false;
    if (MediaQuery.sizeOf(context).width < kWideContentBreakpoint) {
      return false;
    }
    return contentWidth >=
        kEntityRelatedRailWidth + kWideContentPadding + minListBesideRail;
  }

  @override
  Widget build(BuildContext context) {
    final below = related ?? relatedRail;
    if (!wide) {
      return _stacked(about: about, list: list, related: below, cap: false);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final railChild = relatedRail ?? related;
        final showRail = showRelatedRail(
          context,
          constraints.maxWidth,
          hasRelated: about != null || railChild != null,
        );

        if (!showRail) {
          return _stacked(
            about: about,
            list: list,
            related: below,
            cap: capList,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: list),
            const SizedBox(width: kWideContentPadding),
            SizedBox(
              width: kEntityRelatedRailWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?about,
                  if (about != null && railChild != null)
                    const SizedBox(height: 24),
                  ?railChild,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stacked({
    required Widget? about,
    required Widget list,
    required Widget? related,
    required bool cap,
  }) {
    final listChild = cap
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kEntityTrackMaxWidth),
              child: list,
            ),
          )
        : list;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (about != null) ...[about, const SizedBox(height: 16)],
        listChild,
        if (related != null) ...[const SizedBox(height: 24), related],
      ],
    );
  }
}
