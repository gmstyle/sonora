import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/library/library_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/artist/artist_screen.dart';
import '../features/artist/artist_videos_screen.dart';
import '../features/album/album_screen.dart';
import '../features/playlist/playlist_screen.dart';
import '../features/browse_section/browse_section_screen.dart';
import '../features/explore/charts_screen.dart';
import '../features/explore/moods_screen.dart';
import '../features/explore/new_releases_screen.dart';
import '../features/podcast/podcast_screen.dart';
import '../features/user/user_screen.dart';
import '../features/user/user_videos_screen.dart';
import '../features/user/user_playlists_screen.dart';
import '../features/library/widgets/smart_mix_detail_view.dart';
import '../shared/layouts/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _slideUpPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: ArtistScreen(
                            artistId: state.pathParameters['artistId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'videos',
                        pageBuilder: (context, state) {
                          final artistId = state.pathParameters['artistId']!;
                          final name = state.uri.queryParameters['name'];
                          return _slideUpPage(
                            key: state.pageKey,
                            child: ArtistVideosScreen(
                              artistId: artistId,
                              artistName: name,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'album/:albumId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: AlbumScreen(
                            albumId: state.pathParameters['albumId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'playlist/:playlistId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: PlaylistScreen(
                            playlistId: state.pathParameters['playlistId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'smart-mix/:type',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: SmartMixDetailView(
                            type: state.pathParameters['type']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'browse-section/:browseId',
                    pageBuilder: (context, state) {
                      final browseId = state.pathParameters['browseId']!;
                      final params = state.uri.queryParameters['params'];
                      final title =
                          state.uri.queryParameters['title'] ?? 'Section';
                      return _slideUpPage(
                        key: state.pageKey,
                        child: BrowseSectionScreen(
                          browseId: browseId,
                          params: params,
                          title: title,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'charts',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: const ChartsScreen(),
                        ),
                  ),
                  GoRoute(
                    path: 'moods',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: const MoodsScreen(),
                        ),
                    routes: [
                      GoRoute(
                        path: 'playlists',
                        pageBuilder: (context, state) {
                          final params =
                              state.uri.queryParameters['params'] ?? '';
                          final title =
                              state.uri.queryParameters['title'] ?? 'Mood';
                          return _slideUpPage(
                            key: state.pageKey,
                            child: MoodPlaylistsScreen(
                              params: params,
                              title: title,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'new-releases',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: const NewReleasesScreen(),
                        ),
                  ),
                  GoRoute(
                    path: 'podcast/:browseId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: PodcastScreen(
                            browseId: state.pathParameters['browseId']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'user/:channelId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: UserScreen(
                            channelId: state.pathParameters['channelId']!,
                          ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'videos',
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          final params =
                              state.uri.queryParameters['params'] ?? '';
                          return _slideUpPage(
                            key: state.pageKey,
                            child: UserVideosScreen(
                              channelId: channelId,
                              params: params,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'playlists',
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          final params =
                              state.uri.queryParameters['params'] ?? '';
                          return _slideUpPage(
                            key: state.pageKey,
                            child: UserPlaylistsScreen(
                              channelId: channelId,
                              params: params,
                            ),
                          );
                        },
                      ),
                    ],
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
                routes: [
                  GoRoute(
                    path: 'podcast/:browseId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: PodcastScreen(
                            browseId: state.pathParameters['browseId']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'user/:channelId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: UserScreen(
                            channelId: state.pathParameters['channelId']!,
                          ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'videos',
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          final params =
                              state.uri.queryParameters['params'] ?? '';
                          return _slideUpPage(
                            key: state.pageKey,
                            child: UserVideosScreen(
                              channelId: channelId,
                              params: params,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'playlists',
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          final params =
                              state.uri.queryParameters['params'] ?? '';
                          return _slideUpPage(
                            key: state.pageKey,
                            child: UserPlaylistsScreen(
                              channelId: channelId,
                              params: params,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
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
