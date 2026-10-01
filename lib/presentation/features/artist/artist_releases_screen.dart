import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/release_card.dart';
import 'providers/artist_releases_provider.dart';

export 'providers/artist_releases_provider.dart' show ArtistReleaseKind;

class ArtistReleasesScreen extends ConsumerWidget {
  final String artistId;
  final String? artistName;
  final ArtistReleaseKind kind;

  const ArtistReleasesScreen({
    super.key,
    required this.artistId,
    required this.kind,
    this.artistName,
  });

  ArtistReleasesKey get _key => (artistId: artistId, kind: kind);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(artistReleasesProvider(_key));
    final l10n = AppLocalizations.of(context)!;
    final sectionTitle = switch (kind) {
      ArtistReleaseKind.albums => l10n.albums,
      ArtistReleaseKind.singles => l10n.singles,
    };
    final title =
        artistName != null && artistName!.isNotEmpty
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: switch (kind) {
                ArtistReleaseKind.albums => l10n.failedToLoadAlbums,
                ArtistReleaseKind.singles => l10n.failedToLoadSingles,
              },
              onRetry: () => ref.invalidate(artistReleasesProvider(_key)),
            ),
        data: (releases) {
          if (releases.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final width = MediaQuery.sizeOf(context).width;
          final crossAxisCount =
              width < kCompactBreakpoint
                  ? 2
                  : width < kExpandedBreakpoint
                  ? 4
                  : 6;
          final cardWidth =
              (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;
          final releaseType = switch (kind) {
            ArtistReleaseKind.albums => ReleaseType.album,
            ArtistReleaseKind.singles => ReleaseType.single,
          };
          final heroPrefix = switch (kind) {
            ArtistReleaseKind.albums => 'artist_album_all',
            ArtistReleaseKind.singles => 'artist_single_all',
          };

          return RefreshIndicator(
            onRefresh: () => ref.refresh(artistReleasesProvider(_key).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      switch (kind) {
                        ArtistReleaseKind.albums => l10n.albumCount(
                          releases.length,
                        ),
                        ArtistReleaseKind.singles => l10n.singleCount(
                          releases.length,
                        ),
                      },
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final release = releases[index];
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
                    }, childCount: releases.length),
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
