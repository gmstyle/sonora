import 'package:flutter/material.dart';

/// Shared binary affinity control for detail headers (like / follow / subscribe).
///
/// Compact ([iconOnly]): [IconButton]. Wide: [FilledButton.tonalIcon].
/// Active state uses [activeIcon] + [activeColor] (and active label when wide).
class DetailAffinityButton extends StatelessWidget {
  final bool iconOnly;
  final bool isActive;
  final bool enabled;
  final IconData idleIcon;
  final IconData activeIcon;
  final String idleLabel;
  final String activeLabel;
  final String? tooltip;
  final Color? activeColor;
  final VoidCallback? onPressed;

  const DetailAffinityButton({
    super.key,
    required this.iconOnly,
    required this.isActive,
    required this.idleIcon,
    required this.activeIcon,
    required this.idleLabel,
    required this.activeLabel,
    this.tooltip,
    this.activeColor,
    this.onPressed,
    this.enabled = true,
  });

  /// Material heart pair for Like actions (outline → filled).
  static const IconData likeIdle = Icons.favorite_border;
  static const IconData likeActive = Icons.favorite;

  IconData get _icon => isActive ? activeIcon : idleIcon;
  String get _label => isActive ? activeLabel : idleLabel;
  Color? get _color => isActive ? activeColor : null;

  @override
  Widget build(BuildContext context) {
    final tip = tooltip ?? _label;
    if (iconOnly) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(_icon),
        color: _color,
        tooltip: tip,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(_icon),
      label: Text(_label),
      style:
          isActive && activeColor != null
              ? FilledButton.styleFrom(foregroundColor: activeColor)
              : null,
    );
  }
}
