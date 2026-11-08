import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/feed_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'providers/artist_provider.dart';

class ArtistFeaturedScreen extends ConsumerWidget {
  final String artistId;
  final String? artistName;

  const ArtistFeaturedScreen({
    super.key,
    required this.artistId,
    this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));
    final l10n = AppLocalizations.of(context)!;
    final name = artistName;
    final title = name != null && name.isNotEmpty
        ? '${l10n.featuredOn} · $name'
        : l10n.featuredOn;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: artistAsync.when(
        loading: () => const _FeaturedLoadingGrid(),
        error: (e, _) => ErrorRetryWidget(
          message: l10n.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
        data: (artist) {
          final playlists = artist.featuredOn;
          if (playlists.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.maxWidth;
              final isWide = viewport >= kExpandedBreakpoint;
              final contentWidth = isWide && viewport > kDocumentContentMaxWidth
                  ? kDocumentContentMaxWidth
                  : viewport;
              final spec = FeedGridSpec.fromWidth(
                contentWidth,
                shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
              );
              final horizontalPad = spec.horizontalPadding;
              final columns = spec.columns;
              final cardWidth = spec.cardWidth;

              final grid = RefreshIndicator(
                onRefresh: () => ref.refresh(artistProvider(artistId).future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          12,
                          horizontalPad,
                          8,
                        ),
                        child: Text(
                          l10n.playlistCount(playlists.length),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        MediaQuery.paddingOf(context).bottom +
                            (isWide ? 48 : 16),
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: cardWidth / (cardWidth + 64),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final playlist = playlists[index];
                          return PlaylistCard(
                            playlistId: playlist.playlistId,
                            name: playlist.name,
                            artist: displayArtists(playlist.artists),
                            thumbnailUrl: playlist.thumbnails.isNotEmpty
                                ? playlist.thumbnails.last.url
                                : null,
                            cardWidth: cardWidth,
                            heroTag:
                                'artist_featured_all_${playlist.playlistId}',
                          );
                        }, childCount: playlists.length),
                      ),
                    ),
                  ],
                ),
              );

              if (!isWide) return grid;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kDocumentContentMaxWidth,
                  ),
                  child: grid,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeaturedLoadingGrid extends StatelessWidget {
  const _FeaturedLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final isWide = viewport >= kExpandedBreakpoint;
        final contentWidth = isWide && viewport > kDocumentContentMaxWidth
            ? kDocumentContentMaxWidth
            : viewport;
        final spec = FeedGridSpec.fromWidth(
          contentWidth,
          shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
        );
        final horizontalPad = spec.horizontalPadding;
        final columns = spec.columns;
        final cardWidth = spec.cardWidth;
        final grid = GridView.builder(
          padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: cardWidth / (cardWidth + 64),
          ),
          itemCount: columns * 3,
          itemBuilder: (_, _) => ShimmerLoading(
            variant: ShimmerVariant.card,
            cardWidth: cardWidth,
          ),
        );
        if (!isWide) return grid;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kDocumentContentMaxWidth,
            ),
            child: grid,
          ),
        );
      },
    );
  }
}
