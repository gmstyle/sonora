import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/android_tv_provider.dart';
import '../tv/screens/entity/tv_podcast_screen.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../providers/play_podcast_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/entity_shimmer.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/entity_banner_header.dart';
import '../../shared/widgets/header_credit_line.dart';
import '../../shared/widgets/detail_affinity_button.dart';
import 'providers/podcast_provider.dart';

/// Index of [episodeIndex] within the subset of episodes that have a
/// playable [PodcastEpisode.videoId] (matches the filtering performed by
/// [PlayerNotifier.playPodcast] / [PlayPodcastUseCase]).
int playableIndexForEpisode(PodcastFull podcast, int episodeIndex) {
  final episode = podcast.episodes[episodeIndex];
  if (episode.videoId.isEmpty) return -1;
  final playable = podcast.episodes.where((e) => e.videoId.isNotEmpty).toList();
  return playable.indexWhere((e) => e.videoId == episode.videoId);
}

class PodcastScreen extends ConsumerWidget {
  final String browseId;

  const PodcastScreen({super.key, required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAndroidTvProvider)) {
      return TvPodcastScreen(browseId: browseId);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return _PodcastMobileLayout(
            browseId: browseId,
            contentWidth: constraints.maxWidth,
          );
        } else if (size.width < kExpandedBreakpoint) {
          return _PodcastTabletLayout(
            browseId: browseId,
            contentWidth: constraints.maxWidth,
          );
        } else {
          return _PodcastWideLayout(
            browseId: browseId,
            contentWidth: constraints.maxWidth,
          );
        }
      },
    );
  }
}

class _PodcastMobileLayout extends ConsumerWidget {
  final String browseId;
  final double contentWidth;

  const _PodcastMobileLayout({
    required this.browseId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.tracks,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPodcast,
          onRetry: () => ref.invalidate(podcastProvider(browseId)),
        ),
      ),
      data: (podcast) =>
          _PodcastContent(podcast: podcast, contentWidth: contentWidth),
    );
  }
}

class _PodcastTabletLayout extends ConsumerWidget {
  final String browseId;
  final double contentWidth;

  const _PodcastTabletLayout({
    required this.browseId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.tracks,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPodcast,
          onRetry: () => ref.invalidate(podcastProvider(browseId)),
        ),
      ),
      data: (podcast) => _PodcastContent(
        podcast: podcast,
        isTablet: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _PodcastWideLayout extends ConsumerWidget {
  final String browseId;
  final double contentWidth;

  const _PodcastWideLayout({
    required this.browseId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.tracks,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPodcast,
          onRetry: () => ref.invalidate(podcastProvider(browseId)),
        ),
      ),
      data: (podcast) => _PodcastContent(
        podcast: podcast,
        isWide: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _PodcastContent extends ConsumerStatefulWidget {
  final PodcastFull podcast;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;

  const _PodcastContent({
    required this.podcast,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_PodcastContent> createState() => _PodcastContentState();
}

class _PodcastContentState extends ConsumerState<_PodcastContent> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double expandedHeight = EntityBannerHeader.expandedHeight(
      wide: widget.isWide,
      layout: widget.isTablet || widget.isWide
          ? EntityBannerLayout.cover
          : EntityBannerLayout.centered,
    );
    final double collapsedHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;
    final double delta = expandedHeight - collapsedHeight;
    final double progress = (_scrollController.offset / delta).clamp(0.0, 1.0);
    if (progress != _scrollProgress) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _PodcastSliverAppBar(
            podcast: widget.podcast,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
            contentWidth: widget.contentWidth,
            scrollProgress: _scrollProgress,
          ),
          SliverPadding(
            padding: entityBodyPadding(
              widget.contentWidth,
              shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isTablet && !widget.isWide)
                    _PodcastActions(podcast: widget.podcast),
                  const SizedBox(height: 16),
                  EntityWideBody(
                    about:
                        widget.podcast.description != null &&
                            widget.podcast.description!.isNotEmpty
                        ? ExpandableText(text: widget.podcast.description!)
                        : null,
                    list: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.podcast.episodes.length} ${l10n.episodes}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _EpisodeTracklist(podcast: widget.podcast),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastSliverAppBar extends StatelessWidget {
  final PodcastFull podcast;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;
  final double scrollProgress;

  const _PodcastSliverAppBar({
    required this.podcast,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    final thumbnailUrl = podcast.thumbnails.isNotEmpty
        ? podcast.thumbnails.last.url
        : null;
    return SliverAppBar(
      expandedHeight: EntityBannerHeader.expandedHeight(
        wide: isWide,
        layout: isTablet || isWide
            ? EntityBannerLayout.cover
            : EntityBannerLayout.centered,
      ),
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          podcast.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(opacity: scrollProgress),
          FlexibleSpaceBar(
            background: _buildHeaderBackground(context, thumbnailUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context, String? thumbnailUrl) {
    final isTabletOrWide = isTablet || isWide;
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final textAlign = isTabletOrWide ? TextAlign.start : TextAlign.center;
    final author = podcast.author;

    return EntityBannerHeader(
      layout: isTabletOrWide
          ? EntityBannerLayout.cover
          : EntityBannerLayout.centered,
      eyebrow: l10n.entityKindPodcast,
      title: podcast.name,
      meta: Column(
        crossAxisAlignment: isTabletOrWide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (author != null && author.name.isNotEmpty) ...[
            HeaderCreditLine(
              credits: artistCreditSpans([author]),
              style:
                  (isTabletOrWide
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                        fontWeight: isTabletOrWide ? FontWeight.w600 : null,
                        color: colors.titleSecondary,
                      ),
              textAlign: textAlign,
            ),
            SizedBox(height: isTabletOrWide ? 6 : 4),
          ],
          Text(
            '${podcast.episodes.length} ${l10n.episodes}',
            style:
                (isTabletOrWide
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: isTabletOrWide
                          ? colors.subtitle
                          : colors.labelMuted,
                    ),
            textAlign: textAlign,
          ),
        ],
      ),
      imageUrl: thumbnailUrl,
      placeholderIcon: LucideIcons.micVocal,
      scrollProgress: scrollProgress,
      wide: isWide,
      contentWidth: contentWidth,
      actions: _PodcastActions(podcast: podcast),
    );
  }
}

class _PodcastActions extends ConsumerWidget {
  final PodcastFull podcast;

  const _PodcastActions({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasEpisodes = podcast.episodes.any((e) => e.videoId.isNotEmpty);

    final secondary = rankDetailActions([
      DetailAction(
        id: DetailActionId.queue,
        icon: LucideIcons.listMusic,
        label: l10n.addToQueue,
        tooltip: l10n.addToQueue,
        onPressed: hasEpisodes ? () => _addToQueue(context, ref) : null,
      ),
      DetailAction(
        id: DetailActionId.save,
        icon: LucideIcons.bookmark,
        label: l10n.subscribe,
        tooltip: l10n.subscribe,
        buildControl: (context, compact) =>
            _SubscribePodcastButton(podcast: podcast, iconOnly: compact),
      ),
    ]);

    return DetailActionsBar(
      secondary: secondary,
      onPlay: hasEpisodes ? () => _playSequential(context, ref) : null,
      playLabel: l10n.playAll,
      onShuffle: hasEpisodes ? () => _shufflePlay(context, ref) : null,
      shuffleLabel: l10n.shufflePlay,
      alwaysShowOverflow: true,
      onOverflow: () {
        ContextMenuSheet.showForPodcast(
          context,
          browseId: podcast.browseId,
          name: podcast.name,
          author: podcast.author?.name,
          thumbnailUrl: podcast.thumbnails.isNotEmpty
              ? podcast.thumbnails.last.url
              : null,
          omitActionIds: {
            DetailActionId.play,
            DetailActionId.shuffle,
            DetailActionId.queue,
            DetailActionId.save,
          },
        );
      },
    );
  }

  Future<void> _addToQueue(BuildContext context, WidgetRef ref) async {
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playPodcastUseCaseProvider);
    try {
      final episodes = podcast.episodes
          .where((e) => e.videoId.isNotEmpty)
          .toList();
      if (episodes.isEmpty) return;
      final items = await useCase.execute(
        episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        playIndex: -1,
      );
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(AppLocalizations.of(context)!.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add podcast to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToAddToQueue,
              kind: FeedbackKind.error,
            );
      }
    }
  }

  Future<void> _playSequential(BuildContext context, WidgetRef ref) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.playingPlaylist(podcast.name));
    final player = ref.read(playerStateProvider.notifier);
    try {
      await player.playPodcast(
        podcast.episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: 0,
      );
    } catch (e) {
      debugPrint('Failed to play podcast: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
            );
      }
    }
  }

  Future<void> _shufflePlay(BuildContext context, WidgetRef ref) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.shufflingPlaylist(podcast.name));
    final player = ref.read(playerStateProvider.notifier);
    final shuffled = List<PodcastEpisode>.from(podcast.episodes)..shuffle();
    try {
      await player.playPodcast(
        shuffled,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: 0,
      );
    } catch (e) {
      debugPrint('Failed to shuffle play podcast: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
            );
      }
    }
  }
}

class _SubscribePodcastButton extends ConsumerWidget {
  final PodcastFull podcast;
  final bool iconOnly;

  const _SubscribePodcastButton({required this.podcast, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final likedAsync = ref.watch(likedPodcastProvider(podcast.browseId));
    return likedAsync.when(
      loading: () => DetailAffinityButton(
        iconOnly: iconOnly,
        isActive: false,
        enabled: false,
        idleIcon: DetailAffinityButton.bookmarkIdle,
        activeIcon: DetailAffinityButton.bookmarkActive,
        idleLabel: l10n.subscribe,
        activeLabel: l10n.subscribed,
        activeColor: DetailAffinityButton.brandColor(
          Theme.of(context).colorScheme,
        ),
        onPressed: null,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSubscribed = liked != null;
        return DetailAffinityButton(
          iconOnly: iconOnly,
          isActive: isSubscribed,
          idleIcon: DetailAffinityButton.bookmarkIdle,
          activeIcon: DetailAffinityButton.bookmarkActive,
          idleLabel: l10n.subscribe,
          activeLabel: l10n.subscribed,
          activeColor: DetailAffinityButton.brandColor(
            Theme.of(context).colorScheme,
          ),
          onPressed: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedPodcast(
                  LikedPodcastModel(
                    browseId: podcast.browseId,
                    name: podcast.name,
                    authorName: podcast.author?.name,
                    authorId: podcast.author?.artistId,
                    thumbnailUrl: podcast.thumbnails.isNotEmpty
                        ? podcast.thumbnails.last.url
                        : null,
                    episodeCount: podcast.episodes.length,
                    addedAt: DateTime.now(),
                  ),
                );
          },
        );
      },
    );
  }
}

class _EpisodeTracklist extends ConsumerWidget {
  final PodcastFull podcast;

  const _EpisodeTracklist({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authorName = podcast.author?.name ?? podcast.name;

    if (podcast.episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.noContentAvailable,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < podcast.episodes.length; i++)
          SongTile(
            videoId: podcast.episodes[i].videoId,
            title: podcast.episodes[i].name,
            artist: authorName,
            artistId: podcast.author?.artistId,
            thumbnailUrl: podcast.episodes[i].thumbnails.isNotEmpty
                ? podcast.episodes[i].thumbnails.last.url
                : null,
            duration: Parser.parseDuration(podcast.episodes[i].duration),
            playCount: podcast.episodes[i].date,
            isVideo: false,
            onTap: playableIndexForEpisode(podcast, i) >= 0
                ? () => _playFromIndex(
                    context,
                    ref,
                    playableIndexForEpisode(podcast, i),
                  )
                : null,
          ),
      ],
    );
  }

  Future<void> _playFromIndex(
    BuildContext context,
    WidgetRef ref,
    int startIndex,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    try {
      await player.playPodcast(
        podcast.episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: startIndex,
      );
    } catch (e) {
      debugPrint('Failed to play podcast episode: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
            );
      }
    }
  }
}
