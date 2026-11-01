import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

import '../tv_metrics.dart';
import '../tv_shell_focus.dart';

/// Horizontal shelf of focusable TV cards with region memory.
class TvShelf extends StatelessWidget {
  final String title;
  final String memoryKey;
  final List<Widget> children;
  final double height;

  const TvShelf({
    super.key,
    required this.title,
    required this.memoryKey,
    required this.children,
    this.height = TvMetrics.shelfHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TvMetrics.horizontalPadding,
            ),
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: DpadRegion(
              memoryKey: memoryKey,
              debugLabel: memoryKey,
              // Stop at both horizontal ends; Left is bridged to the shell
              // sidebar because branch Navigators isolate FocusScopes.
              horizontalEdge: DpadEdgeBehavior.stop,
              verticalEdge: DpadEdgeBehavior.leave,
              onEdge: (direction) {
                if (direction == TraversalDirection.left) {
                  TvShellFocus.requestSidebar(context);
                }
              },
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: TvMetrics.horizontalPadding,
                  vertical: 4,
                ),
                itemCount: children.length,
                separatorBuilder:
                    (_, _) => const SizedBox(width: TvMetrics.cardGap),
                itemBuilder: (context, index) => children[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
