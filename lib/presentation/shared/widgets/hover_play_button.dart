import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/player_colors.dart';
import 'scale_button.dart';

/// Circular play control shown on card hover. Matches mini / full player
/// branding via [SonoraPulseTokens.playControlDecoration] — never use
/// [ColorScheme.primary] as the fill (it is a light tint in dark mode).
class HoverPlayButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const HoverPlayButton({
    super.key,
    required this.isVisible,
    required this.onTap,
    this.size = 36.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: brandPlayDecoration(context, glow: false),
          child: Center(
            child: Icon(
              LucideIcons.play,
              size: iconSize,
              color: brandGlyphOnFill(context),
            ),
          ),
        ),
      ),
    );
  }
}
