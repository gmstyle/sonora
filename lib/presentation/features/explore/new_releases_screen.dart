import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/release_card.dart';
import '../../shared/widgets/video_card.dart';
import 'providers/explore_provider.dart';

class NewReleasesScreen extends ConsumerWidget {
  const NewReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(exploreNewReleasesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.newReleases,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: releasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadExplore,
              onRetry: () => ref.invalidate(exploreNewReleasesProvider),
            ),
        data: (result) {
          if (result.albums.isEmpty && result.videos.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount =
              width < kCompactBreakpoint
                  ? 2
                  : width < kExpandedBreakpoint
                  ? 4
                  : 6;
          final cardWidth =
              (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(exploreNewReleasesProvider.future),
            child: CustomScrollView(
              slivers: [
                if (result.albums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.searchAlbums,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final album = result.albums[index];
                        return ReleaseCard(
                          albumId: album.albumId,
                          name: album.name,
                          artist: album.artist.name,
                          artistId: album.artist.artistId,
                          thumbnailUrl:
                              album.thumbnails.isNotEmpty
                                  ? album.thumbnails.last.url
                                  : null,
                          year: album.year,
                          type: ReleaseType.album,
                          cardWidth: cardWidth,
                          badgeText: 'NEW',
                          showArtist: true,
                          heroTag: 'explore_new_release_${album.albumId}',
                        );
                      }, childCount: result.albums.length),
                    ),
                  ),
                ],
                if (result.videos.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.videos,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: result.videos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final video = result.videos[index];
                          return VideoCard(
                            videoId: video.videoId,
                            title: video.name,
                            artist: video.artist.name,
                            thumbnailUrl:
                                video.thumbnails.isNotEmpty
                                    ? video.thumbnails.last.url
                                    : null,
                            artistId: video.artist.artistId,
                            isExplicit: video.isExplicit,
                          );
                        },
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
