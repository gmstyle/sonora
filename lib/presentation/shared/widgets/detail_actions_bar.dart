import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../core/utils/layout_breakpoints.dart';
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

  /// Custom control. [compact] is true when rendered as an icon-only control.
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

/// Shared detail-header action chrome:
/// - Left: primary Play CTA + primary affinity action ([DetailActionId.save], if any).
/// - Right: compact glass utility pill with Shuffle, remaining secondaries, and More.
class DetailActionsBar extends StatelessWidget {
  /// Secondary actions (queue, save/follow, download, etc.).
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
    final l10n = AppLocalizations.of(context);
    final isCompact = isCompactShell(MediaQuery.sizeOf(context));

    final visibleSecondary = secondary.take(kSecondaryBudget).toList();
    final overflowed = secondary.skip(kSecondaryBudget).toList();
    final showMore =
        overflowed.isNotEmpty || (onOverflow != null && alwaysShowOverflow);
    // Episode has no shuffle. Callers that pass neither callback nor label
    // keep Play + the secondary actions only.
    final showShuffle = onShuffle != null || shuffleLabel != null;

    final primarySave = visibleSecondary
        .where((a) => a.id == DetailActionId.save)
        .toList();
    final rightSecondary = visibleSecondary
        .where((a) => a.id != DetailActionId.save)
        .toList();

    void openOverflow() {
      if (onOverflow != null) {
        onOverflow!();
        return;
      }
      if (overflowed.isEmpty) return;
      _showOverflowSheet(context, overflowed);
    }

    final rightControls = <Widget>[
      if (showShuffle)
        _CompactIconAction(
          icon: LucideIcons.shuffle,
          tooltip: shuffleLabel ?? l10n?.shufflePlay ?? 'Shuffle',
          onPressed: onShuffle,
        ),
      for (final action in rightSecondary) _UtilityAction(action: action),
      if (showMore)
        _CompactIconAction(
          icon: LucideIcons.moreVertical,
          tooltip: l10n?.more ?? 'More',
          onPressed: openOverflow,
        ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    style: isCompact
                        ? FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          )
                        : null,
                    icon: const Icon(LucideIcons.play, size: 18),
                    label: Text(
                      playLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                for (final action in primarySave) ...[
                  SizedBox(width: isCompact ? 6 : 10),
                  _PrimaryAffinityAction(action: action, compact: isCompact),
                ],
              ],
            ),
          ),
          if (rightControls.isNotEmpty) ...[
            const SizedBox(width: 12),
            _UtilityPill(children: rightControls),
          ],
        ],
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
        builder: (ctx) => Center(
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

class _PrimaryAffinityAction extends StatelessWidget {
  final DetailAction action;
  final bool compact;

  const _PrimaryAffinityAction({required this.action, required this.compact});

  @override
  Widget build(BuildContext context) {
    final built = action.buildControl?.call(context, compact);
    if (built != null) return built;
    if (compact) {
      return _CompactIconAction(
        icon: action.icon,
        tooltip: action.tooltip,
        onPressed: action.onPressed,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 18),
      label: Text(action.label),
    );
  }
}

class _UtilityPill extends StatelessWidget {
  final List<Widget> children;

  const _UtilityPill({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusPill),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _UtilityAction extends StatelessWidget {
  final DetailAction action;

  const _UtilityAction({required this.action});

  @override
  Widget build(BuildContext context) {
    final built = action.buildControl?.call(context, true);
    if (built != null) {
      return IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: built,
      );
    }
    return _CompactIconAction(
      icon: action.icon,
      tooltip: action.tooltip,
      onPressed: action.onPressed,
    );
  }
}

class _CompactIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CompactIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
      tooltip: tooltip,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
