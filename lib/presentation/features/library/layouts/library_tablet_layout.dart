import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../widgets/favorites_tab.dart';
import '../widgets/artists_tab.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/albums_tab.dart';
import '../widgets/history_tab.dart';
import '../widgets/library_header_controls.dart';
import '../widgets/library_search_results_view.dart';
import '../providers/library_provider.dart';

class LibraryTabletLayout extends ConsumerStatefulWidget {
  const LibraryTabletLayout({super.key});

  @override
  ConsumerState<LibraryTabletLayout> createState() =>
      _LibraryTabletLayoutState();
}

class _LibraryTabletLayoutState extends ConsumerState<LibraryTabletLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isAlbumsOrPlaylists =
        _tabController.index == 2 || _tabController.index == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.library,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: false,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSearchActive) ...[
            NavigationRail(
              selectedIndex: _tabController.index,
              onDestinationSelected: (i) => _tabController.animateTo(i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(LucideIcons.heart),
                  selectedIcon: const Icon(LucideIcons.heart),
                  label: Text(AppLocalizations.of(context)!.favorites),
                ),
                NavigationRailDestination(
                  icon: const Icon(LucideIcons.user),
                  selectedIcon: const Icon(LucideIcons.user),
                  label: Text(AppLocalizations.of(context)!.artists),
                ),
                NavigationRailDestination(
                  icon: const Icon(LucideIcons.listVideo),
                  selectedIcon: const Icon(LucideIcons.listVideo),
                  label: Text(AppLocalizations.of(context)!.playlists),
                ),
                NavigationRailDestination(
                  icon: const Icon(LucideIcons.disc),
                  selectedIcon: const Icon(LucideIcons.disc),
                  label: Text(AppLocalizations.of(context)!.albums),
                ),
                NavigationRailDestination(
                  icon: const Icon(LucideIcons.history),
                  selectedIcon: const Icon(LucideIcons.history),
                  label: Text(AppLocalizations.of(context)!.history),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                LibraryHeaderControls(
                  showViewSwitcher: !isSearchActive && isAlbumsOrPlaylists,
                ),
                Expanded(
                  child:
                      isSearchActive
                          ? const LibrarySearchResultsView()
                          : TabBarView(
                            controller: _tabController,
                            children: const [
                              FavoritesTab(),
                              ArtistsTab(),
                              PlaylistsTab(),
                              AlbumsTab(),
                              HistoryTab(),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
