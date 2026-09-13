import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../widgets/battery_prompt_gate.dart';
import '../widgets/offline_banner.dart';
import 'mobile_shell.dart';
import 'tablet_shell.dart';
import 'wide_shell.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Phones in landscape often have width ≥600 but a short side
            // still under compact — keep MobileShell so the rail never
            // fights a ~360px-tall window (A1 / similar).
            final shortestSide = constraints.biggest.shortestSide;
            if (shortestSide < kCompactBreakpoint) {
              return MobileShell(navigationShell: navigationShell);
            } else if (constraints.maxWidth < kExpandedBreakpoint) {
              return TabletShell(navigationShell: navigationShell);
            } else {
              return WideShell(navigationShell: navigationShell);
            }
          },
        ),
        const OfflineBanner(),
        const BatteryPromptGate(),
      ],
    );
  }
}
