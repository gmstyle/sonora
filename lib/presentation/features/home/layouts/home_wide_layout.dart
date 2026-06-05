import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../providers/home_provider.dart';
import '../widgets/home_section_renderer.dart';
import '../../../../l10n/app_localizations.dart';

class HomeWideLayout extends ConsumerWidget {
  const HomeWideLayout({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final artistsAsync = ref.watch(homeRandomArtistsProvider);
    final albumsAsync = ref.watch(homeRandomAlbumsProvider);
    final newReleasesAsync = ref.watch(homeRandomNewReleasesProvider);
    final discoverAsync = ref.watch(homeDiscoverProvider);
    final similarArtistsAsync = ref.watch(homeSimilarArtistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SonoraLogo.icon(28),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                ref.invalidate(homeSectionsProvider);
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
      body: sectionsAsync.when(
        loading: () => const HomeShimmer(tileCount: 4),
        error:
            (e, _) => ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadHomeFeed,
              onRetry: () => ref.invalidate(homeSectionsProvider),
            ),
        data:
            (sections) => RefreshIndicator(
              onRefresh: () => ref.refresh(homeSectionsProvider.future),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (sections.isNotEmpty)
                    HomeSectionRow(
                      section: sections[0],
                      isFirst: true,
                      cardWidth: 180,
                      heroViewportFraction: 0.6,
                      sectionPadding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                    ),
                  HomeYourPlaylists(playlistsAsync, cardWidth: 180),
                  HomeContinueListening(historyAsync, cardWidth: 180),
                  HomeYourArtists(artistsAsync, cardWidth: 160),
                  HomeLikedAlbums(albumsAsync, cardWidth: 180),
                  HomeNewReleases(newReleasesAsync, cardWidth: 180),
                  HomeDiscover(discoverAsync, cardWidth: 180),
                  HomeSimilarArtists(similarArtistsAsync, cardWidth: 160),
                  if (sections.length > 1)
                    for (var i = 1; i < sections.length; i++)
                      HomeSectionRow(
                        section: sections[i],
                        isFirst: false,
                        cardWidth: 180,
                        sectionPadding: const EdgeInsets.fromLTRB(
                          32,
                          24,
                          32,
                          16,
                        ),
                      ),
                ],
              ),
            ),
      ),
    );
  }
}
