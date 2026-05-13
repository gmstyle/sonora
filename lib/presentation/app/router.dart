import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/library/library_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/artist/artist_screen.dart';
import '../features/album/album_screen.dart';
import '../features/playlist/playlist_screen.dart';
import '../shared/layouts/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'artist/:artistId',
                    builder: (context, state) => ArtistScreen(
                      artistId: state.pathParameters['artistId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'album/:albumId',
                    builder: (context, state) => AlbumScreen(
                      albumId: state.pathParameters['albumId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'playlist/:playlistId',
                    builder: (context, state) => PlaylistScreen(
                      playlistId: state.pathParameters['playlistId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder: (context, state) => const DownloadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
