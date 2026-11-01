import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../search/providers/search_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

/// TV search: field + results grid navigable with the D-pad.
class TvSearchScreen extends ConsumerStatefulWidget {
  const TvSearchScreen({super.key});

  @override
  ConsumerState<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends ConsumerState<TvSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (ref.read(isOfflineProvider)) {
      final l10n = AppLocalizations.of(context)!;
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.noConnectionMessage, kind: FeedbackKind.error);
      return;
    }
    ref.read(searchQueryProvider.notifier).update(trimmed);
    await ref.read(activeSearchQueryProvider.notifier).submit(trimmed);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.horizontalPadding,
              TvMetrics.verticalPadding,
              TvMetrics.horizontalPadding,
              16,
            ),
            child: DpadRegion(
              memoryKey: 'tv/search/field',
              debugLabel: 'tv/search/field',
              horizontalEdge: DpadEdgeBehavior.stop,
              onEdge: (direction) {
                if (direction == TraversalDirection.left) {
                  TvShellFocus.requestSidebar(context);
                }
              },
              child: TvFocusable(
                // No autofocus: shell sidebar owns initial focus.
                onSelect: () => _focusNode.requestFocus(),
                excludeChildFocus: false,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: isOffline,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText:
                        isOffline ? l10n.noConnectionMessage : l10n.searchHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 28),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                activeQuery.isEmpty
                    ? EmptyStateWidget(
                      icon: LucideIcons.search,
                      title: l10n.searchForMusic,
                      body: l10n.searchForMusicHint,
                    )
                    : resultsAsync.when(
                      loading:
                          () => const Center(
                            child: ShimmerLoading(
                              variant: ShimmerVariant.section,
                            ),
                          ),
                      error:
                          (_, _) => ErrorRetryWidget(
                            message: l10n.searchFailed,
                            onRetry:
                                () => ref.invalidate(searchResultsProvider),
                          ),
                      data: (results) {
                        if (results.isEmpty) {
                          return EmptyStateWidget(
                            icon: LucideIcons.searchX,
                            title: l10n.noResults,
                            body: activeQuery,
                          );
                        }
                        return DpadRegion(
                          memoryKey: 'tv/search/results',
                          debugLabel: 'tv/search/results',
                          horizontalEdge: DpadEdgeBehavior.stop,
                          onEdge: (direction) {
                            if (direction == TraversalDirection.left) {
                              TvShellFocus.requestSidebar(context);
                            }
                          },
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              TvMetrics.horizontalPadding,
                              8,
                              TvMetrics.horizontalPadding,
                              TvMetrics.verticalPadding,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: TvMetrics.cardWidth + 24,
                                  mainAxisExtent: TvMetrics.cardExtent,
                                  crossAxisSpacing: TvMetrics.cardGap,
                                  mainAxisSpacing: TvMetrics.cardGap,
                                ),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              return _resultCard(context, ref, results[index]);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, WidgetRef ref, SearchResult result) {
    // Search returns SongDetailed / AlbumDetailed / … directly (they implement
    // SearchResult). The *SearchResult wrapper types are unused by the API.
    if (result is SongDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect:
            result.isPlayable
                ? () => ref
                    .read(playerStateProvider.notifier)
                    .playVideoId(
                      result.videoId,
                      isVideo: result.type == 'VIDEO',
                      isExplicit: result.isExplicit,
                    )
                : null,
      );
    }
    if (result is VideoDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect:
            result.isPlayable
                ? () => ref
                    .read(playerStateProvider.notifier)
                    .playVideoId(
                      result.videoId,
                      isVideo: true,
                      isExplicit: result.isExplicit,
                    )
                : null,
      );
    }
    if (result is AlbumDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/album/${result.albumId}'),
      );
    }
    if (result is ArtistDetailed) {
      return TvPosterCard(
        title: result.name,
        circular: true,
        width: 160,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/artist/${result.artistId}'),
      );
    }
    if (result is PlaylistDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/playlist/${result.playlistId}'),
      );
    }
    if (result is PodcastDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: result.author,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/podcast/${result.browseId}'),
      );
    }
    if (result is EpisodeDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: [
          if (result.podcastName != null) result.podcastName!,
          if (result.date != null) result.date!,
        ].join(' · '),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/episode/${result.videoId}'),
      );
    }
    if (result is ProfileDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: result.handle,
        circular: true,
        width: 160,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        onSelect: () => context.push('/user/${result.browseId}'),
      );
    }
    return const SizedBox.shrink();
  }
}
