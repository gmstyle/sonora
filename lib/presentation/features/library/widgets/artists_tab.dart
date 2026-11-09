import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/layout_breakpoints.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/collection_shimmer.dart';
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
      loading: () => LibraryCollectionShimmer(
        grid: isGridView,
        style: LibraryCollectionStyle.artist,
      ),
      error: (e, _) => ErrorRetryWidget(
        message: AppLocalizations.of(context)!.failedToLoadArtists,
        onRetry: () => ref.invalidate(followedArtistsProvider),
      ),
      data: (artists) {
        if (artists.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return EmptyStateWidget(
            icon: LucideIcons.user,
            title: l10n.noFollowedArtists,
            body: l10n.noFollowedArtistsHint,
            buttonLabel: l10n.goToSearch,
            onButtonPressed: () => context.go('/search'),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(followedArtistsProvider.future),
          child: isGridView
              ? GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
                  gridDelegate: libraryCollectionGridDelegate(
                    compact: isCompactShell(MediaQuery.sizeOf(context)),
                    style: LibraryCollectionStyle.artist,
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
