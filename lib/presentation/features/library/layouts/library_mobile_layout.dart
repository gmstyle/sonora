import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora/l10n/app_localizations.dart';

import '../widgets/favorites_tab.dart';
import '../widgets/artists_tab.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/albums_tab.dart';
import '../widgets/history_tab.dart';
import '../widgets/library_header_controls.dart';
import '../widgets/library_search_results_view.dart';
import '../providers/library_provider.dart';

class LibraryMobileLayout extends ConsumerStatefulWidget {
  const LibraryMobileLayout({super.key});

  @override
  ConsumerState<LibraryMobileLayout> createState() =>
      _LibraryMobileLayoutState();
}

class _LibraryMobileLayoutState extends ConsumerState<LibraryMobileLayout>
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
      body: Column(
        children: [
          if (!isSearchActive)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: AppLocalizations.of(context)!.favorites),
                Tab(text: AppLocalizations.of(context)!.artists),
                Tab(text: AppLocalizations.of(context)!.playlists),
                Tab(text: AppLocalizations.of(context)!.albums),
                Tab(text: AppLocalizations.of(context)!.history),
              ],
            ),
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
    );
  }
}
