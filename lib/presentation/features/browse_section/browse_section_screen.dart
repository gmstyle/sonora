import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_card.dart';
import 'providers/browse_section_provider.dart';
import '../../../core/utils/artists_utils.dart';

class BrowseSectionScreen extends ConsumerWidget {
  final String browseId;
  final String? params;
  final String title;

  const BrowseSectionScreen({
    super.key,
    required this.browseId,
    this.params,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(
      browseSectionProvider((browseId: browseId, params: params)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: resultAsync.when(
        loading: () => const _BrowseSectionShimmer(),
        error:
            (err, _) => ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadHomeFeed,
              onRetry:
                  () => ref.invalidate(
                    browseSectionProvider((browseId: browseId, params: params)),
                  ),
            ),
        data: (result) {
          if (result.sections.isEmpty) {
            return Center(
              child: Text(
                'No content available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount =
              width < kCompactBreakpoint
                  ? 2
                  : width < kExpandedBreakpoint
                  ? 4
                  : 6;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16,
                  right: 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final section in result.sections) ...[
                      if (section.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: section.contents.length,
                        itemBuilder: (context, index) {
                          final item = section.contents[index];
                          return _buildGridItem(context, item, width);
                        },
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, dynamic item, double width) {
    final cardWidth = (width - 48) / 2; // Default for mobile 2 columns
    if (item is SongDetailed) {
      return SongCard(
        videoId: item.videoId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        artist: displayArtists(item.artists),
        artists: item.artists,
        duration: item.duration,
        artistId: primaryArtistId(item.artists),
        albumId: item.album?.albumId,
        cardWidth: cardWidth,
        isVideo: item.type == 'VIDEO',
        isExplicit: item.isExplicit,
        isPlayable: item.isPlayable,
      );
    }
    if (item is AlbumDetailed) {
      return AlbumCard(
        albumId: item.albumId,
        name: item.name,
        artist: displayArtists(item.artists),
        artistId: primaryArtistId(item.artists),
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        year: item.year,
        cardWidth: cardWidth,
        heroTag: 'browse_section_album_${item.albumId}',
      );
    }
    if (item is PlaylistDetailed) {
      return PlaylistCard(
        playlistId: item.playlistId,
        name: item.name,
        artist: displayArtists(item.artists),
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        cardWidth: cardWidth,
        heroTag: 'browse_section_playlist_${item.playlistId}',
      );
    }
    return const SizedBox.shrink();
  }
}

class _BrowseSectionShimmer extends StatelessWidget {
  const _BrowseSectionShimmer();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount =
        width < kCompactBreakpoint
            ? 2
            : width < kExpandedBreakpoint
            ? 4
            : 6;
    final cardWidth = (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: crossAxisCount * 3,
      itemBuilder:
          (_, _) => ShimmerLoading(
            variant: ShimmerVariant.card,
            cardWidth: cardWidth,
          ),
    );
  }
}
