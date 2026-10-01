import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/release_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'providers/artist_releases_provider.dart';

export 'providers/artist_releases_provider.dart' show ArtistReleaseKind;

class ArtistReleasesScreen extends ConsumerStatefulWidget {
  final String artistId;
  final String? artistName;
  final ArtistReleaseKind kind;

  const ArtistReleasesScreen({
    super.key,
    required this.artistId,
    required this.kind,
    this.artistName,
  });

  @override
  ConsumerState<ArtistReleasesScreen> createState() =>
      _ArtistReleasesScreenState();
}

class _ArtistReleasesScreenState extends ConsumerState<ArtistReleasesScreen> {
  ArtistReleaseSort _sort = ArtistReleaseSort.year;

  ArtistReleasesKey get _key => (artistId: widget.artistId, kind: widget.kind);

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(artistReleasesProvider(_key));
    final l10n = AppLocalizations.of(context)!;
    final sectionTitle = switch (widget.kind) {
      ArtistReleaseKind.albums => l10n.albums,
      ArtistReleaseKind.singles => l10n.singles,
    };
    final artistName = widget.artistName;
    final title =
        artistName != null && artistName.isNotEmpty
            ? '$sectionTitle · $artistName'
            : sectionTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: releasesAsync.when(
        loading: () => const _ReleasesLoadingGrid(),
        error:
            (e, _) => ErrorRetryWidget(
              message: switch (widget.kind) {
                ArtistReleaseKind.albums => l10n.failedToLoadAlbums,
                ArtistReleaseKind.singles => l10n.failedToLoadSingles,
              },
              onRetry: () => ref.invalidate(artistReleasesProvider(_key)),
            ),
        data: (releases) {
          if (releases.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.maxWidth;
              final isWide = viewport >= kExpandedBreakpoint;
              final contentWidth =
                  isWide && viewport > 1240 ? 1240.0 : viewport;
              final columns =
                  contentWidth < kCompactBreakpoint
                      ? 2
                      : contentWidth < kMediumBreakpoint
                      ? 3
                      : contentWidth < kExpandedBreakpoint
                      ? 4
                      : 5;
              final cardWidth =
                  (contentWidth - 32 - (columns - 1) * 12) / columns;
              final releaseType = switch (widget.kind) {
                ArtistReleaseKind.albums => ReleaseType.album,
                ArtistReleaseKind.singles => ReleaseType.single,
              };
              final heroPrefix = switch (widget.kind) {
                ArtistReleaseKind.albums => 'artist_album_all',
                ArtistReleaseKind.singles => 'artist_single_all',
              };
              final sorted = sortArtistReleases(releases, _sort);

              final grid = RefreshIndicator(
                onRefresh:
                    () => ref.refresh(artistReleasesProvider(_key).future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              switch (widget.kind) {
                                ArtistReleaseKind.albums => l10n.albumCount(
                                  releases.length,
                                ),
                                ArtistReleaseKind.singles => l10n.singleCount(
                                  releases.length,
                                ),
                              },
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: Text(l10n.sortByYear),
                                  selected: _sort == ArtistReleaseSort.year,
                                  showCheckmark: false,
                                  visualDensity: VisualDensity.compact,
                                  onSelected:
                                      (_) =>
                                          _selectSort(ArtistReleaseSort.year),
                                ),
                                ChoiceChip(
                                  label: Text(l10n.sortByTitle),
                                  selected: _sort == ArtistReleaseSort.title,
                                  showCheckmark: false,
                                  visualDensity: VisualDensity.compact,
                                  onSelected:
                                      (_) =>
                                          _selectSort(ArtistReleaseSort.title),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
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
                          final release = sorted[index];
                          return ReleaseCard(
                            albumId: release.albumId,
                            name: release.name,
                            artist: displayArtists(release.artists),
                            artistId: primaryArtistId(release.artists),
                            thumbnailUrl:
                                release.thumbnails.isNotEmpty
                                    ? release.thumbnails.last.url
                                    : null,
                            year: release.year,
                            type: releaseType,
                            cardWidth: cardWidth,
                            heroTag: '${heroPrefix}_${release.albumId}',
                          );
                        }, childCount: sorted.length),
                      ),
                    ),
                  ],
                ),
              );

              if (!isWide) return grid;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: grid,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _selectSort(ArtistReleaseSort sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
  }
}

class _ReleasesLoadingGrid extends StatelessWidget {
  const _ReleasesLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final isWide = viewport >= kExpandedBreakpoint;
        final contentWidth = isWide && viewport > 1240 ? 1240.0 : viewport;
        final columns =
            contentWidth < kCompactBreakpoint
                ? 2
                : contentWidth < kMediumBreakpoint
                ? 3
                : contentWidth < kExpandedBreakpoint
                ? 4
                : 5;
        final cardWidth = (contentWidth - 32 - (columns - 1) * 12) / columns;
        final grid = GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: cardWidth / (cardWidth + 64),
          ),
          itemCount: columns * 3,
          itemBuilder:
              (_, _) => ShimmerLoading(
                variant: ShimmerVariant.card,
                cardWidth: cardWidth,
              ),
        );
        if (!isWide) return grid;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: grid,
          ),
        );
      },
    );
  }
}
