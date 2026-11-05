import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../../core/utils/feed_grid.dart';
import 'providers/explore_provider.dart';
import '../../../core/utils/artists_utils.dart';

class MoodsScreen extends ConsumerWidget {
  const MoodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(moodCategoriesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.moodsAndGenres,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const _MoodCategoriesShimmer(),
        error: (e, _) => ErrorRetryWidget(
          message: l10n.failedToLoadExplore,
          onRetry: () => ref.invalidate(moodCategoriesProvider),
        ),
        data: (result) {
          if (result.sections.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(moodCategoriesProvider.future),
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              children: [
                for (final entry in result.sections.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in entry.value)
                          ActionChip(
                            label: Text(category.title),
                            onPressed: () {
                              final title = Uri.encodeComponent(category.title);
                              final params = Uri.encodeComponent(
                                category.params,
                              );
                              context.push(
                                '/moods/playlists?title=$title&params=$params',
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class MoodPlaylistsScreen extends ConsumerWidget {
  final String params;
  final String title;

  const MoodPlaylistsScreen({
    super.key,
    required this.params,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(moodPlaylistsProvider(params));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: playlistsAsync.when(
        loading: () => const _MoodPlaylistsShimmer(),
        error: (e, _) => ErrorRetryWidget(
          message: l10n.failedToLoadExplore,
          onRetry: () => ref.invalidate(moodPlaylistsProvider(params)),
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final spec = FeedGridSpec.fromWidth(constraints.maxWidth);

              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  spec.horizontalPadding,
                  16,
                  spec.horizontalPadding,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: spec.columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return PlaylistCard(
                    playlistId: playlist.playlistId,
                    name: playlist.name,
                    artist: displayArtists(playlist.artists),
                    thumbnailUrl: playlist.thumbnails.isNotEmpty
                        ? playlist.thumbnails.last.url
                        : null,
                    cardWidth: spec.cardWidth,
                    heroTag: 'mood_playlist_${playlist.playlistId}',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MoodCategoriesShimmer extends StatelessWidget {
  const _MoodCategoriesShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      children: List.generate(
        4,
        (_) => const ShimmerLoading(variant: ShimmerVariant.exploreChips),
      ),
    );
  }
}

class _MoodPlaylistsShimmer extends StatelessWidget {
  const _MoodPlaylistsShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = FeedGridSpec.fromWidth(constraints.maxWidth);

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            spec.horizontalPadding,
            16,
            spec.horizontalPadding,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spec.columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          itemCount: spec.columns * 3,
          itemBuilder: (_, _) => ShimmerLoading(
            variant: ShimmerVariant.card,
            cardWidth: spec.cardWidth,
          ),
        );
      },
    );
  }
}
