import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet_mobile.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
  LucideIcons.settings,
];

class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Reduced nav bar height: 60 px intrinsic + safe-area inset.
    const double navBarIntrinsic = 60.0;
    // Mini player bar height (floating island, no horizontal edge-to-edge).
    const double miniBarHeight = 64.0;
    // Vertical gap between mini bar bottom and nav bar top.
    const double miniBarGap = 8.0;
    final navBarHeight = navBarIntrinsic + bottomInset;

    // With extendBody:true Flutter does NOT automatically add the nav bar
    // height to MediaQuery.padding for children — we must do it manually.
    // We inject the full bottom clearance (nav bar + optional mini player gap)
    // so every child Scaffold/ListView/CustomScrollView respects it without
    // per-screen changes.
    final extraBottom = isPlayerActive ? miniBarHeight + miniBarGap : 0.0;
    final mq = MediaQuery.of(context);
    final childMq = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom + navBarIntrinsic + extraBottom,
      ),
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          MediaQuery(
            data: childMq,
            child: BranchFadeTransition(navigationShell: navigationShell),
          ),
          if (isPlayerActive)
            Positioned(
              left: 0,
              right: 0,
              // Float the island above the nav bar with a small gap.
              bottom: navBarHeight + miniBarGap,
              height: miniBarHeight,
              child: const PlayerSheetMobile(),
            ),
          const PlayerErrorListener(),
          const ActionFeedbackListener(),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final labels = [
                l10n.home,
                l10n.search,
                l10n.library,
                l10n.downloads,
                l10n.settingsLabel,
              ];
              return NavigationBar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.65),
                elevation: 0,
                height: navBarIntrinsic,
                selectedIndex: navigationShell.currentIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                onDestinationSelected:
                    (index) => navigationShell.goBranch(index),
                destinations: [
                  for (var i = 0; i < _icons.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      label: labels[i],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
