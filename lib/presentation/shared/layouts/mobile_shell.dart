import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet_mobile.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
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
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 100;
    final showPlayer = isPlayerActive && !isKeyboardVisible;

    const double navBarIntrinsic = 60.0;
    const double miniBarHeight = PlayerSheetMobile.height;

    final mq = MediaQuery.of(context);
    final childMq = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom + (isKeyboardVisible ? 0.0 : navBarIntrinsic),
      ),
    );

    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final cs = Theme.of(context).colorScheme;

    final navBar = NavigationBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      height: navBarIntrinsic,
      selectedIndex: navigationShell.currentIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      onDestinationSelected: (index) => navigationShell.goBranch(index),
      destinations: [
        for (var i = 0; i < _icons.length; i++)
          NavigationDestination(
            icon: Icon(_icons[i]),
            label: _getLabel(AppLocalizations.of(context)!, i),
          ),
      ],
    );

    Widget dock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPlayer) ...[
          const PlayerSheetMobile(),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ],
        navBar,
      ],
    );

    dock = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child:
          reduceEffects
              ? ColoredBox(color: cs.surfaceContainerHigh, child: dock)
              : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: ColoredBox(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.82),
                  child: dock,
                ),
              ),
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: showPlayer ? miniBarHeight : 0.0),
            child: MediaQuery(
              data: childMq,
              child: BranchFadeTransition(navigationShell: navigationShell),
            ),
          ),
          const PlayerErrorListener(),
          const ActionFeedbackListener(),
        ],
      ),
      bottomNavigationBar: isKeyboardVisible ? null : dock,
    );
  }
}

String _getLabel(AppLocalizations l10n, int index) {
  return [
    l10n.home,
    l10n.search,
    l10n.library,
    l10n.downloads,
    l10n.settingsLabel,
  ][index];
}
