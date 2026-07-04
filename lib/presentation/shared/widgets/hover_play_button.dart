import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'scale_button.dart';

class HoverPlayButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const HoverPlayButton({
    super.key,
    required this.isVisible,
    required this.onTap,
    this.size = 36.0,
    this.iconSize = 20.0,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onPrimary;

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              LucideIcons.play,
              size: iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
