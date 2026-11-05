import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feed_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/release_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/video_card.dart';
import 'providers/explore_provider.dart';
import '../../../core/utils/artists_utils.dart';

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
        loading: () => const _NewReleasesShimmer(),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadExplore,
              onRetry: () => ref.invalidate(exploreNewReleasesProvider),
            ),
        data: (result) {
          if (result.albums.isEmpty && result.videos.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final spec = FeedGridSpec.fromWidth(constraints.maxWidth);
              final crossAxisCount = spec.columns;
              final cardWidth = spec.cardWidth;
              final pad = spec.horizontalPadding;

              return RefreshIndicator(
                onRefresh: () => ref.refresh(exploreNewReleasesProvider.future),
                child: CustomScrollView(
                  slivers: [
                    if (result.albums.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
                          child: Text(
                            l10n.searchAlbums,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.62,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final album = result.albums[index];
                            return ReleaseCard(
                              albumId: album.albumId,
                              name: album.name,
                              artist: displayArtists(album.artists),
                              artistId: primaryArtistId(album.artists),
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
                          padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
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
                            padding: EdgeInsets.symmetric(horizontal: pad),
                            itemCount: result.videos.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final video = result.videos[index];
                              return VideoCard(
                                videoId: video.videoId,
                                title: video.name,
                                artist: displayArtists(video.artists),
                                artists: video.artists,
                                thumbnailUrl:
                                    video.thumbnails.isNotEmpty
                                        ? video.thumbnails.last.url
                                        : null,
                                artistId: primaryArtistId(video.artists),
                                isExplicit: video.isExplicit,
                                isPlayable: video.isPlayable,
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
          );
        },
      ),
    );
  }
}

class _NewReleasesShimmer extends StatelessWidget {
  const _NewReleasesShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = FeedGridSpec.fromWidth(constraints.maxWidth);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spec.horizontalPadding,
                16,
                spec.horizontalPadding,
                0,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: spec.columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, _) => ShimmerLoading(
                    variant: ShimmerVariant.card,
                    cardWidth: spec.cardWidth,
                  ),
                  childCount: spec.columns * 3,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: ShimmerLoading(variant: ShimmerVariant.carousel),
              ),
            ),
          ],
        );
      },
    );
  }
}
