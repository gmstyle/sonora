import 'package:flutter/material.dart';

import '../layouts/home_layout_metrics.dart';

class HomeZoneHeader extends StatelessWidget {
  final String title;
  final HomeLayoutMetrics metrics;
  final bool showDivider;

  const HomeZoneHeader({
    super.key,
    required this.title,
    required this.metrics,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.horizontalPadding,
            metrics.zoneHeaderTop,
            metrics.horizontalPadding,
            metrics.zoneHeaderBottom,
          ),
          child: Text(
            title,
            style: (textTheme.titleLarge ?? textTheme.titleMedium)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.horizontalPadding,
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
