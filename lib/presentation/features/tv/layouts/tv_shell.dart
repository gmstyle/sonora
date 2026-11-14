import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_feedback_listener.dart';
import '../../../shared/widgets/branch_fade_transition.dart';
import '../../../shared/widgets/dock_status_banners.dart';
import '../../../shared/widgets/player_error_listener.dart';
import '../../../shared/widgets/playlist_import_job_host.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../../player/player_sheet.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
];

/// Android TV chrome: icon rail + shared go_router branch content.
///
/// Reuses the same Home / Search / Library / Downloads screens as phone.
/// Focus handoff and 10-foot layouts land in later steps.
class TvShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TvShell({super.key, required this.navigationShell});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  final FocusNode _sidebarFocus = FocusNode(debugLabel: 'tvSidebar');

  @override
  void dispose() {
    _sidebarFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return TvShellFocus(
      focusSidebar: () => _sidebarFocus.requestFocus(),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Focus(
                    focusNode: _sidebarFocus,
                    child: ColoredBox(
                      color: colorScheme.surfaceContainerLow,
                      child: SizedBox(
                        width: TvMetrics.railWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: SonoraLogo.icon(40)),
                            ),
                            Expanded(
                              child: NavigationRail(
                                selectedIndex: navigationShell.currentIndex,
                                onDestinationSelected: navigationShell.goBranch,
                                labelType: NavigationRailLabelType.all,
                                minWidth: TvMetrics.railWidth,
                                destinations: [
                                  for (var i = 0; i < _icons.length; i++)
                                    NavigationRailDestination(
                                      icon: Icon(
                                        _icons[i],
                                        size: TvMetrics.railIconSize,
                                      ),
                                      label: Text(_label(l10n, i)),
                                    ),
                                ],
                              ),
                            ),
                            const _TvSettingsEntry(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        BranchFadeTransition(navigationShell: navigationShell),
                        const PlayerErrorListener(),
                        const ActionFeedbackListener(),
                        const PlaylistImportJobHost(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const DockStatusBanners(),
            const PlayerSheet(),
          ],
        ),
      ),
    );
  }
}

class _TvSettingsEntry extends StatelessWidget {
  const _TvSettingsEntry();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(context)!.settingsLabel;
    final isSelected = GoRouterState.of(context).uri.path == '/settings';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: Tooltip(
        message: label,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: isSelected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                  : null,
              foregroundColor: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => context.push('/settings'),
            child: Icon(LucideIcons.settings, size: TvMetrics.railIconSize),
          ),
        ),
      ),
    );
  }
}

String _label(AppLocalizations l10n, int index) {
  return [l10n.home, l10n.search, l10n.library, l10n.downloads][index];
}
