import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
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
            if (constraints.maxWidth < kCompactBreakpoint) {
              return MobileShell(navigationShell: navigationShell);
            } else if (constraints.maxWidth < kExpandedBreakpoint) {
              return TabletShell(navigationShell: navigationShell);
            } else {
              return WideShell(navigationShell: navigationShell);
            }
          },
        ),
        const OfflineBanner(),
      ],
    );
  }
}
