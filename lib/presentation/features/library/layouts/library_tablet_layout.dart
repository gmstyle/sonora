import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../widgets/favorites_tab.dart';
import '../widgets/artists_tab.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/albums_tab.dart';
import '../widgets/history_tab.dart';
import '../widgets/smart_mixes_tab.dart';
import '../widgets/library_header_controls.dart';
import '../widgets/library_search_results_view.dart';
import '../providers/library_provider.dart';

class LibraryTabletLayout extends ConsumerWidget {
  const LibraryTabletLayout({super.key});

  List<String> _getTabs(BuildContext context) => [
    AppLocalizations.of(context)!.favorites,
    AppLocalizations.of(context)!.artists,
    AppLocalizations.of(context)!.playlists,
    AppLocalizations.of(context)!.albums,
    AppLocalizations.of(context)!.history,
    AppLocalizations.of(context)!.mixes,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(libraryActiveTabProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isListOrGridTab =
        selectedIndex == 1 ||
        selectedIndex == 2 ||
        selectedIndex == 3 ||
        selectedIndex == 5;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.library,
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
                itemCount: _getTabs(context).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ChoiceChip(
                    label: Text(_getTabs(context)[i]),
                    selected: i == selectedIndex,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(libraryActiveTabProvider.notifier).update(i);
                      }
                    },
                  );
                },
              ),
            ),
          LibraryHeaderControls(
            showViewSwitcher: !isSearchActive && isListOrGridTab,
          ),
          const SizedBox(height: 8),
          Expanded(
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
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
