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
import 'history_tab.dart';
import 'smart_mixes_tab.dart';
import 'stats_tab.dart';
import 'library_header_controls.dart';
import 'library_search_results_view.dart';

class _TabItem {
  final String Function(BuildContext) getTitle;
  final IconData icon;

  _TabItem(this.getTitle, this.icon);
}

final _tabs = [
  _TabItem(
    (context) => AppLocalizations.of(context)!.favorites,
    LucideIcons.heart,
  ),
  _TabItem(
    (context) => AppLocalizations.of(context)!.artists,
    LucideIcons.users,
  ),
  _TabItem(
    (context) => AppLocalizations.of(context)!.playlists,
    LucideIcons.listMusic,
  ),
  _TabItem((context) => AppLocalizations.of(context)!.albums, LucideIcons.disc),
  _TabItem(
    (context) => AppLocalizations.of(context)!.history,
    LucideIcons.history,
  ),
  _TabItem(
    (context) => AppLocalizations.of(context)!.mixes,
    LucideIcons.sparkles,
  ),
  _TabItem(
    (context) => AppLocalizations.of(context)!.stats,
    LucideIcons.barChart2,
  ),
];

class LibrarySplitLayout extends ConsumerWidget {
  const LibrarySplitLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1200; // kExpandedBreakpoint

    final selectedIndex = ref.watch(libraryActiveTabProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isListOrGridTab =
        selectedIndex == 1 ||
        selectedIndex == 2 ||
        selectedIndex == 3 ||
        selectedIndex == 5;

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
                  AppLocalizations.of(context)!.library,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    final tab = _tabs[index];
                    final isSelected = index == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ScaleButton(
                        onTap: () {
                          ref
                              .read(libraryActiveTabProvider.notifier)
                              .update(index);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.4)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                tab.icon,
                                color:
                                    isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tab.getTitle(context),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
              if (selectedIndex != 6) ...[
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
                            index: selectedIndex,
                            children: const [
                              FavoritesTab(),
                              ArtistsTab(),
                              PlaylistsTab(),
                              AlbumsTab(),
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
