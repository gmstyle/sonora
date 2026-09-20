import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Canonical ids for [DetailActionsBar] ranking (lower index = higher priority).
abstract final class DetailActionId {
  static const play = 'play';
  static const shuffle = 'shuffle';
  static const queue = 'queue';
  static const save = 'save';
  static const download = 'download';
  static const share = 'share';
  static const radio = 'radio';
  static const rename = 'rename';
  static const sync = 'sync';
  static const unlink = 'unlink';

  /// Play-centric header order: queue + save in bar; download/radio/share in More.
  static const List<String> rankOrder = [
    play,
    shuffle,
    queue,
    save,
    download,
    share,
    radio,
    rename,
    sync,
    unlink,
  ];

  static int rank(String id) {
    final i = rankOrder.indexOf(id);
    return i < 0 ? rankOrder.length : i;
  }
}

/// One header action for [DetailActionsBar].
///
/// Prefer [buildControl] for stateful buttons (like / download / follow).
/// Otherwise the bar builds icon / tonal controls from [icon] + [onPressed].
class DetailAction {
  final String id;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Custom control. [compact] is true on the mobile icon row.
  final Widget Function(BuildContext context, bool compact)? buildControl;

  const DetailAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onPressed,
    this.buildControl,
  });
}

/// Shared detail-header action chrome: Play + Shuffle + 2 secondary + More.
///
/// Fixed on all breakpoints (no per-width budget):
/// - Compact (&lt;600): 2 secondary icons + shuffle + ⋮ + circular Play
/// - Tablet / wide: Play + Shuffle + 2 secondary labeled + ⋮
///
/// Pass exactly the two in-bar secondaries via [secondary] (typically queue +
/// save, or queue + download for local playlists). Overflow / extras open via
/// [onOverflow] (usually [ContextMenuSheet] with [omitActionIds]).
class DetailActionsBar extends StatelessWidget {
  /// The two secondary actions after Play/Shuffle (queue + save, etc.).
  final List<DetailAction> secondary;

  final VoidCallback? onPlay;
  final String playLabel;
  final VoidCallback? onShuffle;
  final String? shuffleLabel;

  /// Opens entity context menu. When non-null, ⋮ is shown whenever there is
  /// overflow **or** [alwaysShowOverflow] is true (e.g. “Go to artist”).
  final VoidCallback? onOverflow;

  /// When true and [onOverflow] is set, always show ⋮ even if nothing
  /// overflowed the secondary budget.
  final bool alwaysShowOverflow;

  /// Always show at most two secondary controls in the bar.
  static const int kSecondaryBudget = 2;

  const DetailActionsBar({
    super.key,
    required this.secondary,
    required this.onPlay,
    required this.playLabel,
    required this.onShuffle,
    this.shuffleLabel,
    this.onOverflow,
    this.alwaysShowOverflow = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < kCompactBreakpoint;

    final visibleSecondary = secondary.take(kSecondaryBudget).toList();
    final overflowed = secondary.skip(kSecondaryBudget).toList();
    final showMore =
        overflowed.isNotEmpty || (onOverflow != null && alwaysShowOverflow);

    void openOverflow() {
      if (onOverflow != null) {
        onOverflow!();
        return;
      }
      if (overflowed.isEmpty) return;
      _showOverflowSheet(context, overflowed);
    }

    if (isCompact) {
      return _MobileBar(
        secondary: visibleSecondary,
        onShuffle: onShuffle,
        onPlay: onPlay,
        showMore: showMore,
        onMore: showMore ? openOverflow : null,
      );
    }

    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(LucideIcons.play),
              label: Text(playLabel),
            ),
            FilledButton.tonalIcon(
              onPressed: onShuffle,
              icon: const Icon(LucideIcons.shuffle),
              label: Text(shuffleLabel ?? l10n?.shufflePlay ?? 'Shuffle'),
            ),
            for (final action in visibleSecondary)
              _WideSecondary(action: action),
            if (showMore)
              IconButton(
                icon: const Icon(LucideIcons.moreVertical),
                tooltip: l10n?.more ?? 'More',
                onPressed: openOverflow,
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showOverflowSheet(
    BuildContext context,
    List<DetailAction> actions,
  ) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;

    Widget buildBody(BuildContext ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                enabled:
                    action.onPressed != null || action.buildControl != null,
                onTap: () {
                  Navigator.pop(ctx);
                  action.onPressed?.call();
                },
              ),
            if (actions.isEmpty) ListTile(title: Text(l10n?.more ?? 'More')),
          ],
        ),
      );
    }

    // Match ContextMenuSheet / §7.3: dialog on wide, sheet below.
    if (wide) {
      return showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder:
            (ctx) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: buildBody(ctx),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: buildBody,
    );
  }
}

class _MobileBar extends StatelessWidget {
  final List<DetailAction> secondary;
  final VoidCallback? onShuffle;
  final VoidCallback? onPlay;
  final bool showMore;
  final VoidCallback? onMore;

  const _MobileBar({
    required this.secondary,
    required this.onShuffle,
    required this.onPlay,
    required this.showMore,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in secondary) _MobileSecondary(action: action),
              IconButton(
                icon: const Icon(LucideIcons.shuffle),
                onPressed: onShuffle,
                tooltip: l10n?.shuffle ?? 'Shuffle',
              ),
              if (showMore)
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical),
                  tooltip: l10n?.more ?? 'More',
                  onPressed: onMore,
                ),
            ],
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: FilledButton(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(LucideIcons.play, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSecondary extends StatelessWidget {
  final DetailAction action;

  const _MobileSecondary({required this.action});

  @override
  Widget build(BuildContext context) {
    final built = action.buildControl?.call(context, true);
    if (built != null) return built;
    return IconButton(
      icon: Icon(action.icon),
      onPressed: action.onPressed,
      tooltip: action.tooltip,
    );
  }
}

class _WideSecondary extends StatelessWidget {
  final DetailAction action;

  const _WideSecondary({required this.action});

  @override
  Widget build(BuildContext context) {
    final built = action.buildControl?.call(context, false);
    if (built != null) return built;
    return FilledButton.tonalIcon(
      onPressed: action.onPressed,
      icon: Icon(action.icon),
      label: Text(action.label),
    );
  }
}

/// Sort [actions] by [DetailActionId.rankOrder], keeping unknown ids last.
List<DetailAction> rankDetailActions(Iterable<DetailAction> actions) {
  final list = actions.toList();
  list.sort(
    (a, b) => DetailActionId.rank(a.id).compareTo(DetailActionId.rank(b.id)),
  );
  return list;
}
