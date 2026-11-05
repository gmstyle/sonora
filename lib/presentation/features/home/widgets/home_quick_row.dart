import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/home_layout_metrics.dart';
import 'home_section_renderer.dart';
import 'home_wrapped_entry.dart';

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

    // Side-by-side already insets the Row; children must not re-apply the
    // same horizontal padding or the two columns drift inward unevenly.
    final sideBySide = metrics.useSideBySideQuickRow;
    final childPad = sideBySide ? 0.0 : metrics.quickRowPadding;

    final continueWidget = HomeContinueListening(
      historyAsync,
      thumbnailSize: metrics.continueThumbnailSize,
      horizontalPadding: childPad,
      showHeader: true,
      maxItems: 5,
    );

    final mixesWidget = HomeYourMixes(
      horizontalPadding: childPad,
      showHeader: !sideBySide,
      compactGrid: true,
    );

    final mixesColumn =
        sideBySide
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeWrappedEntry(metrics: metrics, embedded: true),
                mixesWidget,
              ],
            )
            : mixesWidget;

    if (showContinue && showMixes) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: metrics.zoneGap / 2),
        child:
            sideBySide
                ? Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.quickRowPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 55, child: continueWidget),
                      SizedBox(width: metrics.zoneGap),
                      Expanded(flex: 45, child: mixesColumn),
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
      child: showContinue ? continueWidget : mixesColumn,
    );
  }
}
