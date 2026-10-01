import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/video_card.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';

final artistVideosProvider = FutureProvider.family<List<VideoDetailed>, String>(
  (ref, artistId) {
    final repo = ref.watch(musicRepositoryProvider);
    return repo.getArtistVideos(artistId);
  },
);

class ArtistVideosScreen extends ConsumerWidget {
  final String artistId;
  final String? artistName;

  const ArtistVideosScreen({
    super.key,
    required this.artistId,
    this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _ArtistVideosBody(
          artistId: artistId,
          artistName: artistName,
          viewportWidth: constraints.maxWidth,
        );
      },
    );
  }
}

class _ArtistVideosBody extends ConsumerWidget {
  final String artistId;
  final String? artistName;
  final double viewportWidth;

  const _ArtistVideosBody({
    required this.artistId,
    this.artistName,
    required this.viewportWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(artistVideosProvider(artistId));
    final l10n = AppLocalizations.of(context)!;
    final title =
        artistName != null && artistName!.isNotEmpty
            ? '${l10n.videos} · $artistName'
            : l10n.videos;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: videosAsync.when(
        loading: () => const _VideosLoadingGrid(),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadVideos,
              onRetry: () => ref.invalidate(artistVideosProvider(artistId)),
            ),
        data: (videos) {
          if (videos.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final isMobile = viewportWidth < kCompactBreakpoint;
          final isWide = viewportWidth >= kExpandedBreakpoint;
          final contentWidth =
              isWide && viewportWidth > 1240 ? 1240.0 : viewportWidth;
          final columns =
              contentWidth < kCompactBreakpoint
                  ? 2
                  : contentWidth < kMediumBreakpoint
                  ? 3
                  : contentWidth < kExpandedBreakpoint
                  ? 4
                  : 5;
          final cardWidth = (contentWidth - 32 - (columns - 1) * 12) / columns;
          final canPlay = playableVideos(videos).isNotEmpty;

          final grid = RefreshIndicator(
            onRefresh: () => ref.refresh(artistVideosProvider(artistId).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _VideosHeader(
                    videoCount: videos.length,
                    isMobile: isMobile,
                    onPlayAll:
                        canPlay
                            ? () => _playFromIndex(context, ref, videos, 0)
                            : null,
                    onShuffle:
                        canPlay
                            ? () => _shufflePlay(context, ref, videos)
                            : null,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + (isWide ? 48 : 16),
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: cardWidth / (cardWidth * 9 / 16 + 64),
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final video = videos[index];
                      return VideoCard(
                        videoId: video.videoId,
                        title: video.name,
                        artist: displayArtists(video.artists),
                        artists: video.artists,
                        artistId: primaryArtistId(video.artists),
                        thumbnailUrl:
                            video.thumbnails.isNotEmpty
                                ? video.thumbnails.last.url
                                : null,
                        isExplicit: video.isExplicit,
                        isPlayable: video.isPlayable,
                        cardWidth: cardWidth,
                        onTap:
                            () => _playFromIndex(context, ref, videos, index),
                      );
                    }, childCount: videos.length),
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
      ),
    );
  }

  Future<void> _playFromIndex(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
    int startIndex,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final track = videos[startIndex];
    if (!track.isPlayable) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.trackUnplayable(track.name), kind: FeedbackKind.error);
      return;
    }
    ref.read(actionFeedbackProvider.notifier).report(l10n.playAll);
    try {
      await ref
          .read(playerStateProvider.notifier)
          .playPlaylist(videos, startIndex: startIndex);
    } catch (e) {
      debugPrint('Failed to play artist videos: $e');
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    ref.read(actionFeedbackProvider.notifier).report(l10n.shufflePlay);
    final shuffled = List<VideoDetailed>.from(videos)..shuffle();
    try {
      await ref
          .read(playerStateProvider.notifier)
          .playPlaylist(shuffled, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to shuffle play artist videos: $e');
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }
}

class _VideosHeader extends StatelessWidget {
  final int videoCount;
  final bool isMobile;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  const _VideosHeader({
    required this.videoCount,
    required this.isMobile,
    required this.onPlayAll,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.videoCount(videoCount),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (isMobile)
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FilledButton(
                    onPressed: onPlayAll,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(LucideIcons.play, size: 28),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed: onShuffle,
                  tooltip: l10n.shufflePlay,
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPlayAll,
                  icon: const Icon(LucideIcons.play),
                  label: Text(l10n.playAll),
                ),
                FilledButton.tonalIcon(
                  onPressed: onShuffle,
                  icon: const Icon(LucideIcons.shuffle),
                  label: Text(l10n.shufflePlay),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VideosLoadingGrid extends StatelessWidget {
  const _VideosLoadingGrid();

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
            childAspectRatio: cardWidth / (cardWidth * 9 / 16 + 64),
          ),
          itemCount: columns * 3,
          itemBuilder:
              (_, _) => ShimmerLoading(
                variant: ShimmerVariant.videoCard,
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
