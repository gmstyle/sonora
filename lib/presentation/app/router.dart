import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/library/library_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_shared.dart';
import '../features/artist/artist_releases_screen.dart';
import '../features/artist/artist_screen.dart';
import '../features/artist/artist_videos_screen.dart';
import '../features/album/album_screen.dart';
import '../features/playlist/playlist_screen.dart';
import '../features/browse_section/browse_section_screen.dart';
import '../features/explore/charts_screen.dart';
import '../features/explore/moods_screen.dart';
import '../features/explore/new_releases_screen.dart';
import '../features/podcast/podcast_screen.dart';
import '../features/podcast/episode_screen.dart';
import '../features/user/user_screen.dart';
import '../features/user/user_videos_screen.dart';
import '../features/user/user_playlists_screen.dart';
import '../features/library/widgets/moment_mix_detail_view.dart';
import '../features/library/widgets/smart_mix_detail_view.dart';
import '../features/tv/widgets/tv_branch_focus.dart';
import '../features/tv/widgets/tv_left_to_sidebar.dart';
import '../shared/layouts/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pushed catalog/explore screens: Left-edge D-pad returns toward the TV rail.
Widget _tvPush(String memoryKey, Widget child) {
  return TvLeftToSidebar(memoryKey: memoryKey, child: child);
}

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
    // Inbound sonora:// is owned by app_links (Flutter deeplinking disabled in
    // AndroidManifest). Keep override as a belt-and-suspenders for cold start.
    overridePlatformDefaultLocation: true,
    onException: (context, state, router) {
      // Swallow unknown paths (e.g. /track/…) instead of ErrorScreen.
      debugPrint(
        'GoRouter ignored route ${state.uri} '
        '(deep links handled by SonoraLinkHandler)',
      );
    },
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
                builder:
                    (context, state) => const TvBranchFocus(
                      branchIndex: 0,
                      child: HomeScreen(),
                    ),
                routes: [
                  GoRoute(
                    path: 'artist/:artistId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/artist',
                            ArtistScreen(
                              artistId: state.pathParameters['artistId']!,
                              heroTag: state.uri.queryParameters['heroTag'],
                            ),
                          ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'albums',
                        pageBuilder: (context, state) {
                          final artistId = state.pathParameters['artistId']!;
                          final name = state.uri.queryParameters['name'];
                          return _slideUpPage(
                            key: state.pageKey,
                            child: _tvPush(
                              'tv/artist-albums',
                              ArtistReleasesScreen(
                                artistId: artistId,
                                artistName: name,
                                kind: ArtistReleaseKind.albums,
                              ),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'singles',
                        pageBuilder: (context, state) {
                          final artistId = state.pathParameters['artistId']!;
                          final name = state.uri.queryParameters['name'];
                          return _slideUpPage(
                            key: state.pageKey,
                            child: _tvPush(
                              'tv/artist-singles',
                              ArtistReleasesScreen(
                                artistId: artistId,
                                artistName: name,
                                kind: ArtistReleaseKind.singles,
                              ),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'videos',
                        pageBuilder: (context, state) {
                          final artistId = state.pathParameters['artistId']!;
                          final name = state.uri.queryParameters['name'];
                          return _slideUpPage(
                            key: state.pageKey,
                            child: _tvPush(
                              'tv/artist-videos',
                              ArtistVideosScreen(
                                artistId: artistId,
                                artistName: name,
                              ),
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
                          child: _tvPush(
                            'tv/album',
                            AlbumScreen(
                              albumId: state.pathParameters['albumId']!,
                              heroTag: state.uri.queryParameters['heroTag'],
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'playlist/:playlistId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/playlist',
                            PlaylistScreen(
                              playlistId: state.pathParameters['playlistId']!,
                              heroTag: state.uri.queryParameters['heroTag'],
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'smart-mix/:type',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/smart-mix',
                            SmartMixDetailView(
                              type: state.pathParameters['type']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'moment-mix',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/moment-mix',
                            const MomentMixDetailView(),
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
                        child: _tvPush(
                          'tv/browse-section',
                          BrowseSectionScreen(
                            browseId: browseId,
                            params: params,
                            title: title,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'charts',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush('tv/charts', const ChartsScreen()),
                        ),
                  ),
                  GoRoute(
                    path: 'moods',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush('tv/moods', const MoodsScreen()),
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
                            child: _tvPush(
                              'tv/mood-playlists',
                              MoodPlaylistsScreen(params: params, title: title),
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
                          child: _tvPush(
                            'tv/new-releases',
                            const NewReleasesScreen(),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'podcast/:browseId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/podcast',
                            PodcastScreen(
                              browseId: state.pathParameters['browseId']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'episode/:videoId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/episode',
                            EpisodeScreen(
                              videoId: state.pathParameters['videoId']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'user/:channelId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/user',
                            UserScreen(
                              channelId: state.pathParameters['channelId']!,
                            ),
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
                            child: _tvPush(
                              'tv/user-videos',
                              UserVideosScreen(
                                channelId: channelId,
                                params: params,
                              ),
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
                            child: _tvPush(
                              'tv/user-playlists',
                              UserPlaylistsScreen(
                                channelId: channelId,
                                params: params,
                              ),
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
                builder:
                    (context, state) => const TvBranchFocus(
                      branchIndex: 1,
                      child: SearchScreen(),
                    ),
                routes: [
                  GoRoute(
                    path: 'podcast/:browseId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/search-podcast',
                            PodcastScreen(
                              browseId: state.pathParameters['browseId']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'episode/:videoId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/search-episode',
                            EpisodeScreen(
                              videoId: state.pathParameters['videoId']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'user/:channelId',
                    pageBuilder:
                        (context, state) => _slideUpPage(
                          key: state.pageKey,
                          child: _tvPush(
                            'tv/search-user',
                            UserScreen(
                              channelId: state.pathParameters['channelId']!,
                            ),
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
                            child: _tvPush(
                              'tv/search-user-videos',
                              UserVideosScreen(
                                channelId: channelId,
                                params: params,
                              ),
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
                            child: _tvPush(
                              'tv/search-user-playlists',
                              UserPlaylistsScreen(
                                channelId: channelId,
                                params: params,
                              ),
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
                builder:
                    (context, state) => const TvBranchFocus(
                      branchIndex: 2,
                      child: LibraryScreen(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder:
                    (context, state) => const TvBranchFocus(
                      branchIndex: 3,
                      child: TvLeftToSidebar(
                        memoryKey: 'tv/downloads',
                        child: DownloadsScreen(),
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder:
            (context, state) => SettingsScreen(
              initialCategory: settingsCategoryFromSection(
                state.uri.queryParameters['section'],
              ),
            ),
      ),
    ],
  );
});
