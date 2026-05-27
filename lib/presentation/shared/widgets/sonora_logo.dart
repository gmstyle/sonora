import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SonoraLogo extends StatelessWidget {
  final double size;
  final bool fullLogo;

  const SonoraLogo.icon(this.size, {super.key}) : fullLogo = false;
  const SonoraLogo.full(this.size, {super.key}) : fullLogo = true;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primary;
    final icon = SvgPicture.asset(
      'assets/logo_minimal.svg',
      height: size,
      width: size * (220 / 200),
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );

    if (!fullLogo) return icon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          'SONORA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: tint,
          ),
        ),
      ],
    );
  }
}