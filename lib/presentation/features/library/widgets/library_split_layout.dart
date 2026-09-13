import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
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
import 'library_search_results_view.dart';

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
      LucideIcons.sparkles,
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
            color:
                isSelected
                    ? theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.4,
                    )
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1200; // kExpandedBreakpoint
    final l10n = AppLocalizations.of(context)!;

    final selectedTab = ref.watch(libraryActiveTabProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isListOrGridTab = selectedTab.supportsListGridView;
    final overflowSelected = selectedTab.isOverflow;

    Widget mainRow = Row(
      children: [
        // Left Pane - Master List (Library tabs)
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  l10n.library,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    for (final tab in LibraryTab.primaryTabs)
                      _navRow(
                        context: context,
                        theme: theme,
                        isSelected: tab == selectedTab,
                        icon: _tabMeta(tab).icon,
                        title: _tabMeta(tab).getTitle(context),
                        onTap: () {
                          ref
                              .read(libraryActiveTabProvider.notifier)
                              .update(tab);
                        },
                      ),
                    PopupMenuButton<LibraryTab>(
                      tooltip: l10n.more,
                      initialValue: overflowSelected ? selectedTab : null,
                      offset: const Offset(200, 0),
                      onSelected: (tab) {
                        ref.read(libraryActiveTabProvider.notifier).update(tab);
                      },
                      itemBuilder:
                          (context) => [
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
                          icon:
                              overflowSelected
                                  ? _tabMeta(selectedTab).icon
                                  : LucideIcons.ellipsis,
                          title:
                              overflowSelected
                                  ? _tabMeta(selectedTab).getTitle(context)
                                  : l10n.more,
                          onTap: () {},
                          trailing: Icon(
                            LucideIcons.chevronDown,
                            size: 18,
                            color:
                                overflowSelected
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
          ),
        ),
        // Divider
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        // Right Pane - Detail (Library Content)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedTab.showsHeaderControls) ...[
                LibraryHeaderControls(
                  showViewSwitcher: !isSearchActive && isListOrGridTab,
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child:
                      isSearchActive
                          ? const LibrarySearchResultsView()
                          : IndexedStack(
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
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 48.0 : 16.0,
            vertical: isWide ? 32.0 : 16.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              color: theme.colorScheme.surfaceContainerLow,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: mainRow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
