import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/facet_wide_scaffold.dart';
import '../../../shared/widgets/scale_button.dart';
import '../providers/library_provider.dart';
import 'favorites_tab.dart';
import 'artists_tab.dart';
import 'playlists_tab.dart';
import 'albums_tab.dart';
import 'podcasts_tab.dart';
import 'history_tab.dart';
import 'smart_mixes_tab.dart';
import 'stats_tab.dart';
import 'library_header_controls.dart';

class _TabItem {
  final String Function(BuildContext) getTitle;
  final IconData icon;

  const _TabItem(this.getTitle, this.icon);
}

_TabItem _tabMeta(LibraryTab tab) {
  return switch (tab) {
    LibraryTab.favorites => _TabItem(
      (context) => AppLocalizations.of(context)!.favorites,
      LucideIcons.heart,
    ),
    LibraryTab.artists => _TabItem(
      (context) => AppLocalizations.of(context)!.artists,
      LucideIcons.users,
    ),
    LibraryTab.playlists => _TabItem(
      (context) => AppLocalizations.of(context)!.playlists,
      LucideIcons.listMusic,
    ),
    LibraryTab.albums => _TabItem(
      (context) => AppLocalizations.of(context)!.albums,
      LucideIcons.disc,
    ),
    LibraryTab.podcasts => _TabItem(
      (context) => AppLocalizations.of(context)!.podcasts,
      LucideIcons.mic,
    ),
    LibraryTab.history => _TabItem(
      (context) => AppLocalizations.of(context)!.history,
      LucideIcons.history,
    ),
    LibraryTab.mixes => _TabItem(
      (context) => AppLocalizations.of(context)!.mixes,
      LucideIcons.blend,
    ),
    LibraryTab.stats => _TabItem(
      (context) => AppLocalizations.of(context)!.stats,
      LucideIcons.barChart2,
    ),
  };
}

class LibrarySplitLayout extends ConsumerWidget {
  const LibrarySplitLayout({super.key});

  Widget _navRow({
    required BuildContext context,
    required ThemeData theme,
    required bool isSelected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabRail(BuildContext context, WidgetRef ref, {required bool wide}) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedTab = ref.watch(libraryActiveTabProvider);
    final overflowSelected = selectedTab.isOverflow;
    final headerInset = wide ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(headerInset, 24, 12, 8),
          child: Text(
            l10n.library,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final tab in LibraryTab.primaryTabs)
                _navRow(
                  context: context,
                  theme: theme,
                  isSelected: tab == selectedTab,
                  icon: _tabMeta(tab).icon,
                  title: _tabMeta(tab).getTitle(context),
                  onTap: () {
                    ref.read(libraryActiveTabProvider.notifier).update(tab);
                  },
                ),
              PopupMenuButton<LibraryTab>(
                tooltip: l10n.more,
                initialValue: overflowSelected ? selectedTab : null,
                offset: Offset(wide ? 160 : 200, 0),
                onSelected: (tab) {
                  ref.read(libraryActiveTabProvider.notifier).update(tab);
                },
                itemBuilder: (context) => [
                  for (final tab in LibraryTab.overflowTabs)
                    CheckedPopupMenuItem<LibraryTab>(
                      value: tab,
                      checked: tab == selectedTab,
                      child: Text(_tabMeta(tab).getTitle(context)),
                    ),
                ],
                child: IgnorePointer(
                  child: _navRow(
                    context: context,
                    theme: theme,
                    isSelected: overflowSelected,
                    icon: overflowSelected
                        ? _tabMeta(selectedTab).icon
                        : LucideIcons.ellipsis,
                    title: overflowSelected
                        ? _tabMeta(selectedTab).getTitle(context)
                        : l10n.more,
                    onTap: () {},
                    trailing: Icon(
                      LucideIcons.chevronDown,
                      size: 18,
                      color: overflowSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailPane(
    BuildContext context,
    WidgetRef ref, {
    required bool wide,
  }) {
    final selectedTab = ref.watch(libraryActiveTabProvider);
    final isListOrGridTab = selectedTab.supportsListGridView;
    final showControls = selectedTab.showsHeaderControls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showControls) ...[
          LibraryHeaderControls(showViewSwitcher: isListOrGridTab),
          const SizedBox(height: 8),
        ] else
          SizedBox(height: wide ? 24 : 16),
        Expanded(
          child: Padding(
            // Wide tabs already inset lists by 16. Facet padding supplies the
            // rest so the page inset lands on kWideContentPadding.
            padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 8),
            child: IndexedStack(
              index: selectedTab.index,
              children: const [
                FavoritesTab(),
                ArtistsTab(),
                PlaylistsTab(),
                AlbumsTab(),
                PodcastsTab(),
                HistoryTab(),
                SmartMixesTab(),
                StatsTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context).width;
    final isWide = viewport >= kExpandedBreakpoint;

    final tabRail = _tabRail(context, ref, wide: isWide);
    final detail = _detailPane(context, ref, wide: isWide);

    // Tablet 600–1199 keeps the full-bleed split. Wide drops the card.
    final Widget body;
    if (!isWide) {
      body = Row(
        children: [
          SizedBox(width: kFacetFilterRailWidth, child: tabRail),
          VerticalDivider(
            width: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(child: detail),
        ],
      );
    } else {
      body = FacetWideScaffold(
        // Tab bodies already pad ~16. 16 here plus that inset is 32.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kWideContentPadding - 16,
        ),
        filterRail: tabRail,
        child: detail,
      );
    }

    return Scaffold(backgroundColor: theme.colorScheme.surface, body: body);
  }
}
