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
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../search/providers/ask_search_provider.dart';
import '../../search/providers/search_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

/// TV search: field + Ask/filter chips + results grid navigable with the D-pad.
class TvSearchScreen extends ConsumerStatefulWidget {
  const TvSearchScreen({super.key});

  @override
  ConsumerState<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends ConsumerState<TvSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focusFirstResult = false;

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
    _controller.text = trimmed;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: trimmed.length),
    );
    ref.read(searchQueryProvider.notifier).update(trimmed);
    _focusNode.unfocus();
    await ref.read(askSearchSubmitProvider.notifier).submit(trimmed);
    if (!mounted) return;
    setState(() => _focusFirstResult = true);
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(activeSearchQueryProvider.notifier).update('');
    ref.read(askInterpretationProvider.notifier).clear();
    setState(() => _focusFirstResult = false);
    _focusNode.requestFocus();
  }

  List<String> _filterOptions(AppLocalizations l10n) {
    return [
      l10n.all,
      l10n.songs,
      l10n.searchArtists,
      l10n.searchAlbums,
      l10n.searchPlaylists,
      l10n.searchPodcasts,
      l10n.searchEpisodes,
      l10n.searchProfiles,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final filter = ref.watch(searchFilterProvider);
    final askEnabled = ref.watch(askModeEnabledProvider);
    final modelReadyAsync = ref.watch(askLlmReadyProvider);
    final modelReady = modelReadyAsync.asData?.value ?? false;
    final askSubmit = ref.watch(askSearchSubmitProvider);
    final asking = askSubmit.isLoading;
    final theme = Theme.of(context);
    final askReady = askEnabled && modelReady;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.horizontalPadding,
              TvMetrics.verticalPadding,
              TvMetrics.horizontalPadding,
              12,
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
                  readOnly: isOffline || asking,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText:
                        isOffline
                            ? l10n.noConnectionMessage
                            : askReady
                            ? l10n.askSearchHint
                            : l10n.searchHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 28),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                      maxWidth: 48,
                      maxHeight: 48,
                    ),
                    suffixIcon:
                        asking
                            ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                            : query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 24),
                              onPressed: _clearSearch,
                            )
                            : null,
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
                  onChanged:
                      isOffline || asking
                          ? null
                          : (value) {
                            ref
                                .read(searchQueryProvider.notifier)
                                .update(value);
                            final interp = ref.read(askInterpretationProvider);
                            if (interp != null &&
                                value != interp.originalQuery) {
                              ref
                                  .read(askInterpretationProvider.notifier)
                                  .clear();
                            }
                          },
                  onSubmitted: isOffline || asking ? null : _submit,
                ),
              ),
            ),
          ),
          _TvSearchChipRow(
            askReady: askReady,
            askEnabled: askEnabled,
            modelReady: modelReady,
            isOffline: isOffline,
            showFilters: activeQuery.isNotEmpty,
            filter: filter,
            filterOptions: _filterOptions(l10n),
            onAskSelected: (selected) {
              if (!modelReady) {
                ref
                    .read(actionFeedbackProvider.notifier)
                    .report(l10n.askModelRequired, kind: FeedbackKind.error);
                return;
              }
              ref.read(askModeEnabledProvider.notifier).setEnabled(selected);
            },
            onFilterSelected: (index) {
              ref.read(searchFilterProvider.notifier).update(index);
              setState(() => _focusFirstResult = true);
            },
          ),
          _TvAskBanner(
            onPlayed: () => setState(() => _focusFirstResult = false),
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
                        final focusFirst = _focusFirstResult;
                        if (focusFirst) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _focusFirstResult) {
                              setState(() => _focusFirstResult = false);
                            }
                          });
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
                              return _resultCard(
                                context,
                                ref,
                                results[index],
                                autofocus: focusFirst && index == 0,
                              );
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

  Widget _resultCard(
    BuildContext context,
    WidgetRef ref,
    SearchResult result, {
    bool autofocus = false,
  }) {
    // Search returns SongDetailed / AlbumDetailed / … directly (they implement
    // SearchResult). The *SearchResult wrapper types are unused by the API.
    if (result is SongDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        autofocus: autofocus,
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
        autofocus: autofocus,
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
        autofocus: autofocus,
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
        autofocus: autofocus,
        onSelect: () => context.push('/artist/${result.artistId}'),
      );
    }
    if (result is PlaylistDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        autofocus: autofocus,
        onSelect: () => context.push('/playlist/${result.playlistId}'),
      );
    }
    if (result is PodcastDetailed) {
      return TvPosterCard(
        title: result.name,
        subtitle: result.author,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        autofocus: autofocus,
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
        autofocus: autofocus,
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
        autofocus: autofocus,
        onSelect: () => context.push('/user/${result.browseId}'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TvSearchChipRow extends StatelessWidget {
  final bool askReady;
  final bool askEnabled;
  final bool modelReady;
  final bool isOffline;
  final bool showFilters;
  final int filter;
  final List<String> filterOptions;
  final ValueChanged<bool> onAskSelected;
  final ValueChanged<int> onFilterSelected;

  const _TvSearchChipRow({
    required this.askReady,
    required this.askEnabled,
    required this.modelReady,
    required this.isOffline,
    required this.showFilters,
    required this.filter,
    required this.filterOptions,
    required this.onAskSelected,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: DpadRegion(
        memoryKey: 'tv/search/chips',
        debugLabel: 'tv/search/chips',
        horizontalEdge: DpadEdgeBehavior.stop,
        onEdge: (direction) {
          if (direction == TraversalDirection.left) {
            TvShellFocus.requestSidebar(context);
          }
        },
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: TvMetrics.horizontalPadding,
          ),
          children: [
            _TvChip(
              label: l10n.askChip,
              icon: LucideIcons.sparkles,
              selected: askReady,
              enabled: !isOffline,
              onSelect: () => onAskSelected(!(askEnabled && modelReady)),
            ),
            if (showFilters) ...[
              const SizedBox(width: 12),
              for (var i = 0; i < filterOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _TvChip(
                  label: filterOptions[i],
                  selected: filter == i,
                  onSelect: () => onFilterSelected(i),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TvChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;

  const _TvChip({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TvFocusable(
      enabled: enabled,
      onSelect: onSelect,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color:
              selected
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color:
                    selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color:
                    selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvAskBanner extends ConsumerWidget {
  final VoidCallback? onPlayed;

  const _TvAskBanner({this.onPlayed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interpretation = ref.watch(askInterpretationProvider);
    if (interpretation == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(searchResultsProvider);
    final songs =
        resultsAsync.asData?.value.whereType<SongDetailed>().toList() ??
        const <SongDetailed>[];
    final canPlay = songs.isNotEmpty && !ref.watch(isOfflineProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvMetrics.horizontalPadding,
        4,
        TvMetrics.horizontalPadding,
        8,
      ),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.askInterpretedAs,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      interpretation.intent.displayLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canPlay)
                TvFocusable(
                  onSelect: () {
                    onPlayed?.call();
                    ref.read(playerStateProvider.notifier).playAlbum(songs);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.play,
                      color: scheme.primary,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
