import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/home_layout_metrics.dart';
import 'home_section_renderer.dart';

class HomeQuickRow extends ConsumerWidget {
  final AsyncValue historyAsync;
  final HomeLayoutMetrics metrics;

  const HomeQuickRow({
    super.key,
    required this.historyAsync,
    required this.metrics,
  });

  static bool mixesHasContent() => true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showContinue = asyncHistoryHasContent(historyAsync);
    final showMixes = mixesHasContent();

    if (!showContinue && !showMixes) return const SizedBox.shrink();

    final continueWidget = HomeContinueListening(
      historyAsync,
      thumbnailSize: metrics.continueThumbnailSize,
      horizontalPadding: metrics.quickRowPadding,
      showHeader: !metrics.useSideBySideQuickRow,
      maxItems: 5,
    );

    final mixesWidget = HomeYourMixes(
      horizontalPadding: metrics.quickRowPadding,
      showHeader: !metrics.useSideBySideQuickRow,
      compactGrid: true,
    );

    if (showContinue && showMixes) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: metrics.zoneGap / 2),
        child:
            metrics.useSideBySideQuickRow
                ? Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.quickRowPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 55, child: continueWidget),
                      SizedBox(width: metrics.zoneGap),
                      Expanded(flex: 45, child: mixesWidget),
                    ],
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    continueWidget,
                    SizedBox(height: metrics.zoneGap),
                    mixesWidget,
                  ],
                ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: metrics.zoneGap / 2),
      child: showContinue ? continueWidget : mixesWidget,
    );
  }
}
