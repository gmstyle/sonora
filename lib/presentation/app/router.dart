import 'package:flutter/material.dart';
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
import '../features/browse_section/browse_section_screen.dart';
import '../features/library/widgets/smart_mix_detail_view.dart';
import '../shared/layouts/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

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
                        (context, state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: ArtistScreen(
                            artistId: state.pathParameters['artistId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
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
                          reverseTransitionDuration: const Duration(
                            milliseconds: 250,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'album/:albumId',
                    pageBuilder:
                        (context, state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: AlbumScreen(
                            albumId: state.pathParameters['albumId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
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
                          reverseTransitionDuration: const Duration(
                            milliseconds: 250,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'playlist/:playlistId',
                    pageBuilder:
                        (context, state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: PlaylistScreen(
                            playlistId: state.pathParameters['playlistId']!,
                            heroTag: state.uri.queryParameters['heroTag'],
                          ),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
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
                          reverseTransitionDuration: const Duration(
                            milliseconds: 250,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'smart-mix/:type',
                    pageBuilder:
                        (context, state) => CustomTransitionPage(
                          key: state.pageKey,
                          child: SmartMixDetailView(
                            type: state.pathParameters['type']!,
                          ),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
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
                          reverseTransitionDuration: const Duration(
                            milliseconds: 250,
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
                      return CustomTransitionPage(
                        key: state.pageKey,
                        child: BrowseSectionScreen(
                          browseId: browseId,
                          params: params,
                          title: title,
                        ),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondaryAnimation,
                          child,
                        ) {
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
                        reverseTransitionDuration: const Duration(
                          milliseconds: 250,
                        ),
                      );
                    },
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
