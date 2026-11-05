import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Wide facet chrome: sticky filter rail, fluid center, optional utility rail.
///
/// The page stays edge-to-edge. This does not clamp width and does not wrap
/// the body in a [Card]. [showUtility] is for viewports at
/// [kWideContentBreakpoint] and above.
class FacetWideScaffold extends StatelessWidget {
  final Widget filterRail;
  final Widget child;
  final Widget? utilityRail;
  final bool showUtility;
  final EdgeInsetsGeometry contentPadding;

  const FacetWideScaffold({
    super.key,
    required this.filterRail,
    required this.child,
    this.utilityRail,
    this.showUtility = false,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: kWideContentPadding,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant
        .withValues(alpha: 0.4);
    final showRail = showUtility && utilityRail != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: kFacetFilterRailWidth, child: filterRail),
        VerticalDivider(width: 1, color: outline),
        Expanded(
          child: Padding(padding: contentPadding, child: child),
        ),
        if (showRail) ...[
          VerticalDivider(width: 1, color: outline),
          SizedBox(width: kFacetUtilityRailWidth, child: utilityRail),
        ],
      ],
    );
  }
}

/// Media-shelf columns for a facet results column.
///
/// Scales from 2 to 5 as [contentWidth] grows. About 220px per card, matching
/// the wide facet schema (3 columns near 800px, 4 near 1100px, 5 from 1200px).
int facetMediaColumnCount(double contentWidth) {
  const gap = 12.0;
  const minCardWidth = 220.0;
  if (!contentWidth.isFinite || contentWidth <= 0) return 2;
  final count = ((contentWidth + gap) / (minCardWidth + gap)).floor();
  if (count < 2) return 2;
  if (count > 5) return 5;
  return count;
}
