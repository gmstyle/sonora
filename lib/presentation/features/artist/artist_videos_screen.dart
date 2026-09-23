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
import '../../shared/widgets/song_tile.dart';
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
        final isMobile = constraints.maxWidth < kCompactBreakpoint;
        final isWide = constraints.maxWidth >= kExpandedBreakpoint;
        return _ArtistVideosBody(
          artistId: artistId,
          artistName: artistName,
          isMobile: isMobile,
          isWide: isWide,
        );
      },
    );
  }
}

class _ArtistVideosBody extends ConsumerWidget {
  final String artistId;
  final String? artistName;
  final bool isMobile;
  final bool isWide;

  const _ArtistVideosBody({
    required this.artistId,
    this.artistName,
    required this.isMobile,
    required this.isWide,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadVideos,
              onRetry: () => ref.invalidate(artistVideosProvider(artistId)),
            ),
        data: (videos) {
          if (videos.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final list = RefreshIndicator(
            onRefresh: () => ref.refresh(artistVideosProvider(artistId).future),
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).padding.bottom + (isWide ? 48 : 16),
              ),
              itemCount: videos.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final canPlay = playableVideos(videos).isNotEmpty;
                  return _VideosHeader(
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
                  );
                }

                final video = videos[index - 1];
                final i = index - 1;
                return SongTile(
                  videoId: video.videoId,
                  title: video.name,
                  artist: displayArtists(video.artists),
                  artists: video.artists,
                  artistId: primaryArtistId(video.artists),
                  thumbnailUrl:
                      video.thumbnails.isNotEmpty
                          ? video.thumbnails.last.url
                          : null,
                  duration: video.duration,
                  playCount: video.viewCount,
                  isVideo: true,
                  isExplicit: video.isExplicit,
                  isPlayable: video.isPlayable,
                  onTap: () => _playFromIndex(context, ref, videos, i),
                );
              },
            ),
          );

          if (!isWide && isMobile) return list;

          // Tablet / wide: same tracklist language as library detail panes,
          // with a readable max width on large screens.
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1240 : double.infinity,
              ),
              child: list,
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
