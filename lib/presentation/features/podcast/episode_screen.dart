import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/android_tv_provider.dart';
import '../tv/screens/entity/tv_episode_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/link/sonora_link.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/detail_affinity_button.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/entity_banner_header.dart';
import '../../shared/widgets/header_credit_line.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/entity_shimmer.dart';
import 'providers/episode_provider.dart';

class EpisodeScreen extends ConsumerWidget {
  final String videoId;

  const EpisodeScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAndroidTvProvider)) {
      return TvEpisodeScreen(videoId: videoId);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return _EpisodeMobileLayout(
            videoId: videoId,
            contentWidth: constraints.maxWidth,
          );
        } else if (size.width < kExpandedBreakpoint) {
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
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.episode,
          contentWidth: contentWidth,
        ),
      ),
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
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.episode,
          contentWidth: contentWidth,
        ),
      ),
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
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.episode,
          contentWidth: contentWidth,
        ),
      ),
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
            padding: entityBodyPadding(
              widget.contentWidth,
              shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isTablet && !widget.isWide)
                    _EpisodeActions(episode: widget.episode),
                  const SizedBox(height: 16),
                  EntityWideBody(
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
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final textAlign = isTabletOrWide ? TextAlign.start : TextAlign.center;

    return EntityBannerHeader(
      layout: isTabletOrWide
          ? EntityBannerLayout.cover
          : EntityBannerLayout.centered,
      eyebrow: l10n.entityKindEpisode,
      title: episode.name,
      meta: Column(
        crossAxisAlignment: isTabletOrWide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (episode.podcastName != null &&
              episode.podcastName!.isNotEmpty) ...[
            HeaderCreditLine(
              credits: [
                CreditSpan(
                  episode.podcastName!,
                  route:
                      episode.podcastId != null && episode.podcastId!.isNotEmpty
                      ? '/podcast/${episode.podcastId}'
                      : null,
                ),
              ],
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
          if (episode.date != null)
            Text(
              episode.date!,
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
      placeholderIcon: LucideIcons.headphones,
      scrollProgress: scrollProgress,
      wide: isWide,
      contentWidth: contentWidth,
      actions: _EpisodeActions(episode: episode),
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    final likedAsync = ref.watch(likedEpisodeProvider(episode.videoId));

    return likedAsync.when(
      loading: () => DetailAffinityButton(
        iconOnly: iconOnly,
        isActive: false,
        enabled: false,
        idleIcon: DetailAffinityButton.bookmarkIdle,
        activeIcon: DetailAffinityButton.bookmarkActive,
        idleLabel: l10n.saveEpisode,
        activeLabel: l10n.unsaveEpisode,
        activeColor: DetailAffinityButton.brandColor(scheme),
        onPressed: null,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSaved = liked != null;
        return DetailAffinityButton(
          iconOnly: iconOnly,
          isActive: isSaved,
          idleIcon: DetailAffinityButton.bookmarkIdle,
          activeIcon: DetailAffinityButton.bookmarkActive,
          idleLabel: l10n.saveEpisode,
          activeLabel: l10n.unsaveEpisode,
          activeColor: DetailAffinityButton.brandColor(scheme),
          tooltip: isSaved ? l10n.unsaveEpisode : l10n.saveEpisode,
          onPressed: () => _toggle(ref),
        );
      },
    );
  }

  Future<void> _toggle(WidgetRef ref) async {
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
