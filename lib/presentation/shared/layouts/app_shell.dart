import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/layout_breakpoints.dart';
import '../../features/tv/layouts/tv_shell.dart';
import '../../providers/android_tv_provider.dart';
import '../widgets/ask_intro_gate.dart';
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
    final isTv = ref.watch(isAndroidTvProvider);

    return Stack(
      children: [
        if (isTv)
          TvShell(navigationShell: navigationShell)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // Phones in landscape often have width ≥600 but a short side
              // still under compact — keep MobileShell so the rail never
              // fights a ~360px-tall window (A1 / similar).
              final size = constraints.biggest;
              if (isCompactShell(size)) {
                return MobileShell(navigationShell: navigationShell);
              } else if (isTabletShell(size)) {
                return TabletShell(navigationShell: navigationShell);
              } else {
                return WideShell(navigationShell: navigationShell);
              }
            },
          ),
        const OfflineBanner(),
        if (!isTv) const AskIntroGate(),
        if (!isTv) const BatteryPromptGate(),
      ],
    );
  }
}
