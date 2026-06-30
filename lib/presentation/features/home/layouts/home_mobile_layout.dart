import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/app_lifecycle_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../providers/home_provider.dart';
import '../widgets/home_section_renderer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';

class HomeMobileLayout extends ConsumerWidget {
  const HomeMobileLayout({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLifecycleProvider);
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final artistsAsync = ref.watch(homeRandomArtistsProvider);
    final albumsAsync = ref.watch(homeRandomAlbumsProvider);
    final newReleasesAsync = ref.watch(homeRandomNewReleasesProvider);
    final discoverAsync = ref.watch(homeDiscoverProvider);
    final similarArtistsAsync = ref.watch(homeSimilarArtistsProvider);
    final activeChipParams = ref.watch(homeSelectedChipParamsProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          spacing: 8,
          children: [
            const SonoraLogo.icon(22),
            Text(
              _getGreeting(context),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (Platform.isLinux)
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: AppLocalizations.of(context)!.refresh,
              onPressed: () {
                ref.invalidate(homeResultProvider);
                ref.invalidate(recentHistoryProvider);
                ref.invalidate(homeCombinedPlaylistsProvider);
                ref.invalidate(homeRandomPlaylistsProvider);
                ref.invalidate(homeRandomArtistsProvider);
                ref.invalidate(homeRandomAlbumsProvider);
                ref.invalidate(homeNewReleasesProvider);
                ref.invalidate(homeRandomNewReleasesProvider);
                ref.invalidate(homeDiscoverProvider);
                ref.invalidate(homeSimilarArtistsProvider);
              },
            ),
        ],
      ),
      body: AmbientBackground(
        child:
            isOffline
                ? RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(recentHistoryProvider);
                    ref.invalidate(homeCombinedPlaylistsProvider);
                    ref.invalidate(homeRandomPlaylistsProvider);
                    ref.invalidate(homeRandomArtistsProvider);
                    ref.invalidate(homeRandomAlbumsProvider);
                  },
                  child: ListView(
                    padding: EdgeInsets.only(
                      top:
                          MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          8,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              spacing: 16,
                              children: [
                                Icon(
                                  LucideIcons.wifiOff,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.offlineModeActiveMessage,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      HomeYourPlaylists(playlistsAsync, cardWidth: 140),
                      HomeContinueListening(historyAsync, cardWidth: 140),
                      HomeYourArtists(artistsAsync, cardWidth: 120),
                      HomeLikedAlbums(albumsAsync, cardWidth: 140),
                    ],
                  ),
                )
                : sectionsAsync.when(
                  loading: () => const HomeShimmer(),
                  error:
                      (e, _) => ErrorRetryWidget(
                        message:
                            AppLocalizations.of(context)!.failedToLoadHomeFeed,
                        onRetry: () => ref.invalidate(homeResultProvider),
                      ),
                  data:
                      (sections) => RefreshIndicator(
                        onRefresh: () => ref.refresh(homeResultProvider.future),
                        child: ListView(
                          padding: EdgeInsets.only(
                            top:
                                MediaQuery.of(context).padding.top +
                                kToolbarHeight +
                                8,
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                          ),
                          children: [
                            const HomeChipsBar(),
                            if (activeChipParams == null) ...[
                              if (sections.isNotEmpty)
                                HomeSectionRow(
                                  section: sections[0],
                                  isFirst: true,
                                  cardWidth: 140,
                                  onShowAll:
                                      sections[0].browseId != null
                                          ? () {
                                            final titleEncoded =
                                                Uri.encodeComponent(
                                                  sections[0].title,
                                                );
                                            final paramsEncoded =
                                                sections[0].browseParams != null
                                                    ? '&params=${sections[0].browseParams}'
                                                    : '';
                                            context.push(
                                              '/browse-section/${sections[0].browseId}?title=$titleEncoded$paramsEncoded',
                                            );
                                          }
                                          : null,
                                ),
                              HomeYourPlaylists(playlistsAsync, cardWidth: 140),
                              HomeContinueListening(
                                historyAsync,
                                cardWidth: 140,
                              ),
                              HomeYourArtists(artistsAsync, cardWidth: 120),
                              HomeLikedAlbums(albumsAsync, cardWidth: 140),
                              HomeNewReleases(newReleasesAsync, cardWidth: 140),
                              HomeDiscover(discoverAsync, cardWidth: 140),
                              HomeSimilarArtists(
                                similarArtistsAsync,
                                cardWidth: 120,
                              ),
                              if (sections.length > 1)
                                for (var i = 1; i < sections.length; i++)
                                  HomeSectionRow(
                                    section: sections[i],
                                    isFirst: false,
                                    cardWidth: 140,
                                    onShowAll:
                                        sections[i].browseId != null
                                            ? () {
                                              final titleEncoded =
                                                  Uri.encodeComponent(
                                                    sections[i].title,
                                                  );
                                              final paramsEncoded =
                                                  sections[i].browseParams !=
                                                          null
                                                      ? '&params=${sections[i].browseParams}'
                                                      : '';
                                              context.push(
                                                '/browse-section/${sections[i].browseId}?title=$titleEncoded$paramsEncoded',
                                              );
                                            }
                                            : null,
                                  ),
                            ] else ...[
                              if (sections.isNotEmpty)
                                HomeSectionRow(
                                  section: sections[0],
                                  isFirst: true,
                                  cardWidth: 140,
                                  onShowAll:
                                      sections[0].browseId != null
                                          ? () {
                                            final titleEncoded =
                                                Uri.encodeComponent(
                                                  sections[0].title,
                                                );
                                            final paramsEncoded =
                                                sections[0].browseParams != null
                                                    ? '&params=${sections[0].browseParams}'
                                                    : '';
                                            context.push(
                                              '/browse-section/${sections[0].browseId}?title=$titleEncoded$paramsEncoded',
                                            );
                                          }
                                          : null,
                                ),
                              if (sections.length > 1)
                                for (var i = 1; i < sections.length; i++)
                                  HomeSectionRow(
                                    section: sections[i],
                                    isFirst: false,
                                    cardWidth: 140,
                                    onShowAll:
                                        sections[i].browseId != null
                                            ? () {
                                              final titleEncoded =
                                                  Uri.encodeComponent(
                                                    sections[i].title,
                                                  );
                                              final paramsEncoded =
                                                  sections[i].browseParams !=
                                                          null
                                                      ? '&params=${sections[i].browseParams}'
                                                      : '';
                                              context.push(
                                                '/browse-section/${sections[i].browseId}?title=$titleEncoded$paramsEncoded',
                                              );
                                            }
                                            : null,
                                  ),
                            ],
                          ],
                        ),
                      ),
                ),
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour >= 5 && hour < 12) {
      return l10n.goodMorning;
    } else if (hour >= 12 && hour < 18) {
      return l10n.goodAfternoon;
    } else {
      return l10n.goodEvening;
    }
  }
}
