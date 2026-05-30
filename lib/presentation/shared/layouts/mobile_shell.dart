import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';

final _icons = const [
  Icons.home,
  Icons.search,
  Icons.library_music,
  Icons.download,
  Icons.settings,
];

class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;
    const double navBarHeight = 80.0;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: isPlayerActive ? 72.0 + navBarHeight : navBarHeight,
            ),
            child: BranchFadeTransition(navigationShell: navigationShell),
          ),
          PlayerSheet(bottom: navBarHeight),
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
                selectedIndex: navigationShell.currentIndex,
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
