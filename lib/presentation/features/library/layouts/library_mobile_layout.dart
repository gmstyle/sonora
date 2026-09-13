import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sonora/l10n/app_localizations.dart';

import '../widgets/favorites_tab.dart';
import '../widgets/artists_tab.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/albums_tab.dart';
import '../widgets/podcasts_tab.dart';
import '../widgets/history_tab.dart';
import '../widgets/smart_mixes_tab.dart';
import '../widgets/stats_tab.dart';
import '../widgets/library_header_controls.dart';
import '../widgets/library_search_results_view.dart';
import '../providers/library_provider.dart';

class LibraryMobileLayout extends ConsumerWidget {
  const LibraryMobileLayout({super.key});

  String _tabLabel(BuildContext context, LibraryTab tab) {
    final l10n = AppLocalizations.of(context)!;
    return switch (tab) {
      LibraryTab.favorites => l10n.favorites,
      LibraryTab.artists => l10n.artists,
      LibraryTab.playlists => l10n.playlists,
      LibraryTab.albums => l10n.albums,
      LibraryTab.podcasts => l10n.podcasts,
      LibraryTab.history => l10n.history,
      LibraryTab.mixes => l10n.mixes,
      LibraryTab.stats => l10n.stats,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(libraryActiveTabProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isListOrGridTab = selectedTab.supportsListGridView;
    final l10n = AppLocalizations.of(context)!;
    final primaryTabs = LibraryTab.primaryTabs;
    final overflowSelected = selectedTab.isOverflow;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          l10n.library,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSearchActive)
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: primaryTabs.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i < primaryTabs.length) {
                    final tab = primaryTabs[i];
                    return ChoiceChip(
                      label: Text(_tabLabel(context, tab)),
                      selected: tab == selectedTab,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(libraryActiveTabProvider.notifier)
                              .update(tab);
                        }
                      },
                    );
                  }

                  return PopupMenuButton<LibraryTab>(
                    tooltip: l10n.more,
                    initialValue: overflowSelected ? selectedTab : null,
                    onSelected: (tab) {
                      ref.read(libraryActiveTabProvider.notifier).update(tab);
                    },
                    itemBuilder:
                        (context) => [
                          for (final tab in LibraryTab.overflowTabs)
                            CheckedPopupMenuItem<LibraryTab>(
                              value: tab,
                              checked: tab == selectedTab,
                              child: Text(_tabLabel(context, tab)),
                            ),
                        ],
                    child: IgnorePointer(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              overflowSelected
                                  ? _tabLabel(context, selectedTab)
                                  : l10n.more,
                            ),
                            const SizedBox(width: 2),
                            const Icon(LucideIcons.chevronDown, size: 16),
                          ],
                        ),
                        selected: overflowSelected,
                        onSelected: (_) {},
                      ),
                    ),
                  );
                },
              ),
            ),
          if (selectedTab.showsHeaderControls) ...[
            LibraryHeaderControls(
              showViewSwitcher: !isSearchActive && isListOrGridTab,
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
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
        ],
      ),
    );
  }
}
