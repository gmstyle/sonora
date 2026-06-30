import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/artist_tile.dart';
import '../../../shared/widgets/artist_card.dart';
import '../providers/library_provider.dart';

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sortedFollowedArtistsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return async.when(
      loading: () => const _ShimmerArtistList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadArtists,
            onRetry: () => ref.invalidate(followedArtistsProvider),
          ),
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.user,
            title: AppLocalizations.of(context)!.noFollowedArtists,
            body: AppLocalizations.of(context)!.noFollowedArtistsHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(followedArtistsProvider.future),
          child:
              isGridView
                  ? GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      bottomPadding + 16,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140.0,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: artists.length,
                    itemBuilder: (_, i) {
                      final a = artists[i];
                      return ArtistCard(
                        artistId: a.artistId,
                        name: a.name,
                        thumbnailUrl: a.thumbnailUrl,
                        heroTag: 'library_artists_${a.artistId}',
                      );
                    },
                  )
                  : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 8),
                    itemCount: artists.length,
                    itemBuilder: (_, i) {
                      final a = artists[i];
                      return ArtistTile(
                        artistId: a.artistId,
                        name: a.name,
                        thumbnailUrl: a.thumbnailUrl,
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _ShimmerArtistList extends StatelessWidget {
  const _ShimmerArtistList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder:
          (_, _) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ShimmerLoading(variant: ShimmerVariant.tile),
          ),
    );
  }
}
