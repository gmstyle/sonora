import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/link/sonora_link.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'providers/episode_provider.dart';

class EpisodeScreen extends ConsumerWidget {
  final String videoId;

  const EpisodeScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _EpisodeMobileLayout(
            videoId: videoId,
            contentWidth: constraints.maxWidth,
          );
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _EpisodeTabletLayout(
            videoId: videoId,
            contentWidth: constraints.maxWidth,
          );
        } else {
          return _EpisodeWideLayout(
            videoId: videoId,
            contentWidth: constraints.maxWidth,
          );
        }
      },
    );
  }
}

class _EpisodeMobileLayout extends ConsumerWidget {
  final String videoId;
  final double contentWidth;

  const _EpisodeMobileLayout({
    required this.videoId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading: () => const Scaffold(body: _EpisodeShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadEpisode,
          onRetry: () => ref.invalidate(episodeProvider(videoId)),
        ),
      ),
      data: (episode) =>
          _EpisodeContent(episode: episode, contentWidth: contentWidth),
    );
  }
}

class _EpisodeTabletLayout extends ConsumerWidget {
  final String videoId;
  final double contentWidth;

  const _EpisodeTabletLayout({
    required this.videoId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading: () => const Scaffold(body: _EpisodeShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadEpisode,
          onRetry: () => ref.invalidate(episodeProvider(videoId)),
        ),
      ),
      data: (episode) => _EpisodeContent(
        episode: episode,
        isTablet: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _EpisodeWideLayout extends ConsumerWidget {
  final String videoId;
  final double contentWidth;

  const _EpisodeWideLayout({required this.videoId, required this.contentWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading: () => const Scaffold(body: _EpisodeShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadEpisode,
          onRetry: () => ref.invalidate(episodeProvider(videoId)),
        ),
      ),
      data: (episode) => _EpisodeContent(
        episode: episode,
        isWide: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _EpisodeContent extends ConsumerStatefulWidget {
  final EpisodeFull episode;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;

  const _EpisodeContent({
    required this.episode,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_EpisodeContent> createState() => _EpisodeContentState();
}

class _EpisodeContentState extends ConsumerState<_EpisodeContent> {
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
    final double expandedHeight = widget.isTablet || widget.isWide
        ? 360.0
        : 340.0;
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
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _EpisodeSliverAppBar(
            episode: widget.episode,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
            contentWidth: widget.contentWidth,
            scrollProgress: _scrollProgress,
          ),
          SliverPadding(
            padding: entityBodyPadding(widget.contentWidth),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EpisodeActions(episode: widget.episode),
                  const SizedBox(height: 16),
                  EntityWideBody(
                    wide: widget.isWide,
                    list:
                        widget.episode.description != null &&
                            widget.episode.description!.isNotEmpty
                        ? ExpandableText(text: widget.episode.description!)
                        : const SizedBox.shrink(),
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

class _EpisodeSliverAppBar extends StatelessWidget {
  final EpisodeFull episode;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;
  final double scrollProgress;

  const _EpisodeSliverAppBar({
    required this.episode,
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

    final thumbnailUrl = episode.thumbnails.isNotEmpty
        ? episode.thumbnails.last.url
        : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          episode.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    final horizontalPad = entityHorizontalPadding(contentWidth);
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isTabletOrWide) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          _artworkTopScrim(context),
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            bottom: 12,
            left: horizontalPad,
            right: horizontalPad,
            child: Opacity(
              opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (thumbnailUrl != null)
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _placeholder(context),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        LucideIcons.headphones,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    episode.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.podcastName != null &&
                      episode.podcastName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.podcastName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.titleSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (episode.date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.date!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.labelMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Opacity(
                opacity: 0.35,
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                theme.colorScheme.surface.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
        _artworkTopScrim(context),
        Positioned(
          top: 80 + MediaQuery.of(context).padding.top,
          bottom: 24,
          left: horizontalPad,
          right: horizontalPad,
          child: Opacity(
            opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (thumbnailUrl != null)
                  Container(
                    width: isWide ? 190 : 150,
                    height: isWide ? 190 : 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholder(context),
                      ),
                    ),
                  )
                else
                  _placeholder(context),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        l10n.episode.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: colors.labelMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode.name,
                        style:
                            (isWide
                                    ? theme.textTheme.headlineLarge
                                    : theme.textTheme.headlineMedium)
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.titlePrimary,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (episode.podcastName != null &&
                          episode.podcastName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          episode.podcastName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.titleSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (episode.date != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          episode.date!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.subtitle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    width: isWide ? 190 : 150,
    height: isWide ? 190 : 150,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Icon(
      LucideIcons.headphones,
      size: 80,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _EpisodeActions extends ConsumerWidget {
  final EpisodeFull episode;

  const _EpisodeActions({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final podcastId = episode.podcastId;
    final hasPodcast = podcastId != null && podcastId.isNotEmpty;

    return DetailActionsBar(
      onPlay: () => _play(context, ref, episode),
      playLabel: l10n.playNow,
      onShuffle: null,
      secondary: [
        DetailAction(
          id: DetailActionId.save,
          icon: LucideIcons.bookmark,
          label: l10n.saveEpisode,
          tooltip: l10n.saveEpisode,
          buildControl: (context, compact) =>
              _SaveEpisodeButton(episode: episode, iconOnly: compact),
        ),
        if (hasPodcast)
          DetailAction(
            id: 'goToPodcast',
            icon: LucideIcons.micVocal,
            label: l10n.goToPodcast,
            tooltip: l10n.goToPodcast,
            onPressed: () => context.push('/podcast/$podcastId'),
          ),
        DetailAction(
          id: DetailActionId.share,
          icon: LucideIcons.share2,
          label: l10n.share,
          tooltip: l10n.share,
          onPressed: () => _share(context, ref, episode),
        ),
      ],
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    EpisodeFull episode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await shareSonoraLink(
      SonoraLink(kind: SonoraLinkKind.episode, id: episode.videoId),
      title: episode.name,
      subtitle: episode.podcastName,
    );
    if (result == SonoraShareResult.copied && context.mounted) {
      ref.read(actionFeedbackProvider.notifier).report(l10n.linkCopied);
    }
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    EpisodeFull episode,
  ) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.playingPlaylist(episode.name));
    final player = ref.read(playerStateProvider.notifier);
    final podcastEpisode = PodcastEpisode(
      videoId: episode.videoId,
      browseId: episode.browseId,
      name: episode.name,
      description: episode.description,
      duration: episode.duration,
      date: episode.date,
      thumbnails: episode.thumbnails,
    );
    try {
      await player.playPodcast(
        [podcastEpisode],
        podcastBrowseId: episode.podcastId ?? episode.browseId,
        podcastName: episode.podcastName,
        authorName: episode.podcastName,
      );
    } catch (e) {
      debugPrint('Failed to play episode: $e');
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

class _SaveEpisodeButton extends ConsumerWidget {
  final EpisodeFull episode;
  final bool iconOnly;

  const _SaveEpisodeButton({required this.episode, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final likedAsync = ref.watch(likedEpisodeProvider(episode.videoId));

    return likedAsync.when(
      loading: () => iconOnly
          ? const IconButton(onPressed: null, icon: Icon(LucideIcons.bookmark))
          : FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(LucideIcons.bookmark),
              label: Text(l10n.saveEpisode),
            ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSaved = liked != null;
        if (iconOnly) {
          return IconButton(
            onPressed: () => _toggle(ref, isSaved),
            icon: Icon(
              isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
            ),
            color: isSaved ? Theme.of(context).colorScheme.primary : null,
            tooltip: isSaved ? l10n.unsaveEpisode : l10n.saveEpisode,
          );
        }
        return FilledButton.tonalIcon(
          onPressed: () => _toggle(ref, isSaved),
          icon: Icon(
            isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
          ),
          label: Text(isSaved ? l10n.unsaveEpisode : l10n.saveEpisode),
          style: isSaved
              ? FilledButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                )
              : null,
        );
      },
    );
  }

  Future<void> _toggle(WidgetRef ref, bool isSaved) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);
    await notifier.toggleLikedEpisode(
      LikedEpisodeModel(
        videoId: episode.videoId,
        browseId: episode.browseId,
        name: episode.name,
        podcastName: episode.podcastName,
        podcastBrowseId: episode.podcastId,
        thumbnailUrl: episode.thumbnails.isNotEmpty
            ? episode.thumbnails.last.url
            : null,
        durationSec: Parser.parseDuration(episode.duration),
        date: episode.date,
        addedAt: DateTime.now(),
      ),
    );
  }
}

class _EpisodeShimmer extends StatelessWidget {
  const _EpisodeShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: ShimmerLoading(variant: ShimmerVariant.tile),
                    ),
                    SizedBox(width: 12),
                    const Expanded(
                      child: ShimmerLoading(variant: ShimmerVariant.tile),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  4,
                  (_) => const ShimmerLoading(variant: ShimmerVariant.tile),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Top dark scrim for artwork headers — reads colours from [PlayerColors].
Widget _artworkTopScrim(BuildContext context) {
  final pc = PlayerColors.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.20, 0.32],
        colors: [pc.topScrimStart, pc.topScrimMid, Colors.transparent],
      ),
    ),
  );
}
