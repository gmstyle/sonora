import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import 'tv_focusable.dart';

/// Canvas-style section header with colored vertical pill accent and uppercase label.
class TvSectionHeader extends StatelessWidget {
  final String title;
  final Color? accentColor;
  final Widget? trailing;

  const TvSectionHeader({
    super.key,
    required this.title,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(
        left: TvMetrics.contentPadding,
        right: TvMetrics.contentPadding,
        bottom: TvMetrics.shelfTitleGap,
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 15,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: TvColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Horizontal shelf of focusable children with a section title.
class TvShelf extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;
  final Color? accentColor;

  const TvShelf({
    super.key,
    required this.title,
    required this.children,
    this.onSeeAll,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvSectionHeader(
            title: title,
            accentColor: accentColor,
            trailing: onSeeAll != null
                ? TvFocusable(
                    onSelect: onSeeAll,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TvColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TvColors.border),
                      ),
                      child: const Text(
                        '…',
                        style: TextStyle(color: TvColors.textSecondary),
                      ),
                    ),
                  )
                : null,
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
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          TvShellFocus.requestSidebar(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Helper: Left-edge callback for the first item in a shelf.
VoidCallback tvShelfRequestSidebar(BuildContext context) {
  return () => TvShellFocus.requestSidebar(context);
}
