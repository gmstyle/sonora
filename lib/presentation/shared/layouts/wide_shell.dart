import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';
import '../widgets/sonora_logo.dart';
import '../widgets/thumbnail_widget.dart';
import '../widgets/scale_button.dart';
import '../../features/player/full_player_content.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
  LucideIcons.settings,
];

class WideShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const WideShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  DrawerHeader(child: const SonoraLogo.full(44)),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < _icons.length; i++)
                          Stack(
                            children: [
                              ListTile(
                                selected: navigationShell.currentIndex == i,
                                selectedTileColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.5),
                                leading: Icon(_icons[i]),
                                title: Text(
                                  _getLabel(AppLocalizations.of(context)!, i),
                                ),
                                onTap: () => navigationShell.goBranch(i),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                              ),
                              if (navigationShell.currentIndex == i)
                                Positioned(
                                  left: 0,
                                  top: 10,
                                  bottom: 10,
                                  width: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const _NowPlayingPanel(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: isPlayerActive ? 72.0 : 0.0),
child: BranchFadeTransition(navigationShell: navigationShell),
                ),
                const PlayerSheet(),
                const PlayerErrorListener(),
                const ActionFeedbackListener(),
              ],
            ),
          ),
        ],
      ),
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

class _NowPlayingPanel extends ConsumerWidget {
  const _NowPlayingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ScaleButton(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const FullPlayerContent(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;

                var tween = Tween(
                  begin: begin,
                  end: end,
                ).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 350),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              fullscreenDialog: true,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ThumbnailWidget(
                imageUrl: currentSong.artUri?.toString(),
                size:
                    224, // 280 width - 32 parent padding - 24 container padding = 224px perfect fit!
                shape: ThumbnailShape.rounded,
              ),
              const SizedBox(height: 12),
              Text(
                currentSong.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                currentSong.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
