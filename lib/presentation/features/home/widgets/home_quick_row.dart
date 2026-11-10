import 'package:material_ui/material_ui.dart';
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

    // Tablet and wide keep the two columns while history is loading or empty,
    // so the mixes stay on the right. The paired row insets once. A single
    // column keeps the page padding on the child.
    final sideBySide = metrics.useSideBySideQuickRow;
    final showPlaceholder =
        sideBySide &&
        showMixes &&
        !showContinue &&
        historyAsync.hasValue &&
        !historyAsync.hasError;
    final paired =
        sideBySide &&
        showMixes &&
        (showContinue || showPlaceholder || historyAsync.isLoading);
    final childPad = paired ? 0.0 : metrics.quickRowPadding;

    final continueWidget = HomeContinueListening(
      historyAsync,
      thumbnailSize: metrics.continueThumbnailSize,
      horizontalPadding: childPad,
      showHeader: true,
      maxItems: 5,
      placeholderWhenEmpty: showPlaceholder,
    );

    final mixesWidget = HomeYourMixes(
      horizontalPadding: childPad,
      showHeader: true,
      compactGrid: true,
      maxCardWidth: metrics.mixCardMaxWidth,
    );

    final mixesColumn = sideBySide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeWrappedEntry(metrics: metrics, embedded: true),
              mixesWidget,
            ],
          )
        : mixesWidget;

    if (paired) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: metrics.zoneGap / 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.quickRowPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 55,
                child: showContinue || showPlaceholder
                    ? continueWidget
                    : const SizedBox.shrink(),
              ),
              SizedBox(width: metrics.zoneGap),
              Expanded(flex: 45, child: mixesColumn),
            ],
          ),
        ),
      );
    }

    if (showContinue && showMixes) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: metrics.zoneGap / 2),
        child: Column(
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
