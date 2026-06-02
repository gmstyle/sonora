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

class LibraryWideLayout extends ConsumerStatefulWidget {
  const LibraryWideLayout({super.key});

  @override
  ConsumerState<LibraryWideLayout> createState() => _LibraryWideLayoutState();
}

class _LibraryWideLayoutState extends ConsumerState<LibraryWideLayout> {
  int _selectedIndex = 0;

  List<String> _getTabs(BuildContext context) => [
    AppLocalizations.of(context)!.favorites,
    AppLocalizations.of(context)!.artists,
    AppLocalizations.of(context)!.playlists,
    AppLocalizations.of(context)!.albums,
    AppLocalizations.of(context)!.history,
  ];

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(librarySearchQueryProvider);
    final isSearchActive = query.trim().isNotEmpty;
    final isAlbumsOrPlaylists = _selectedIndex == 2 || _selectedIndex == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.library,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: false,
      ),
      body: Row(
        children: [
          if (!isSearchActive) ...[
            SizedBox(
              width: 240,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  ...List.generate(_getTabs(context).length, (i) {
                    final icons = [
                      LucideIcons.heart,
                      LucideIcons.user,
                      LucideIcons.listVideo,
                      LucideIcons.disc,
                      LucideIcons.history,
                    ];
                    return ListTile(
                      selected: i == _selectedIndex,
                      leading: Icon(icons[i]),
                      title: Text(_getTabs(context)[i]),
                      onTap: () => setState(() => _selectedIndex = i),
                    );
                  }),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LibraryHeaderControls(
                    showViewSwitcher: !isSearchActive && isAlbumsOrPlaylists,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        isSearchActive
                            ? const LibrarySearchResultsView()
                            : IndexedStack(
                              index: _selectedIndex,
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
          ),
        ],
      ),
    );
  }
}
