import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';
import '../tv_shell_focus.dart';

/// Horizontal shelf of focusable children with a section title.
class TvShelf extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  const TvShelf({
    super.key,
    required this.title,
    required this.children,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: TvMetrics.contentPadding,
              right: TvMetrics.contentPadding,
              bottom: TvMetrics.shelfTitleGap,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(onPressed: onSeeAll, child: const Text('…')),
              ],
            ),
          ),
          SizedBox(
            height: TvMetrics.shelfRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TvMetrics.contentPadding,
                vertical: 12,
              ),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final child = children[index];
                if (index == 0) {
                  return _ShelfLeadingFocus(child: child);
                }
                return child;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ensures Left on the first shelf item requests the sidebar when the child
/// did not already wire [TvFocusable.onLeftAtEdge].
class _ShelfLeadingFocus extends StatelessWidget {
  final Widget child;

  const _ShelfLeadingFocus({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Helper: Left-edge callback for the first item in a shelf.
VoidCallback tvShelfRequestSidebar(BuildContext context) {
  return () => TvShellFocus.requestSidebar(context);
}
