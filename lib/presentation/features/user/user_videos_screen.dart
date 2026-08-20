import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/song_tile.dart';
import 'providers/user_provider.dart';

class UserVideosScreen extends ConsumerWidget {
  final String channelId;
  final String params;
  final String? userName;

  const UserVideosScreen({
    super.key,
    required this.channelId,
    required this.params,
    this.userName,
  });

  UserContentParams get _key => (channelId: channelId, params: params);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < kCompactBreakpoint;
        final isWide = constraints.maxWidth >= kExpandedBreakpoint;
        return _UserVideosBody(
          contentKey: _key,
          userName: userName,
          isMobile: isMobile,
          isWide: isWide,
        );
      },
    );
  }
}

class _UserVideosBody extends ConsumerWidget {
  final UserContentParams contentKey;
  final String? userName;
  final bool isMobile;
  final bool isWide;

  const _UserVideosBody({
    required this.contentKey,
    this.userName,
    required this.isMobile,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(userVideosProvider(contentKey));
    final l10n = AppLocalizations.of(context)!;
    final title =
        userName != null && userName!.isNotEmpty
            ? '${l10n.videos} · $userName'
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
              onRetry: () => ref.invalidate(userVideosProvider(contentKey)),
            ),
        data: (videos) {
          if (videos.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final list = RefreshIndicator(
            onRefresh: () => ref.refresh(userVideosProvider(contentKey).future),
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).padding.bottom + (isWide ? 48 : 16),
              ),
              itemCount: videos.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _VideosHeader(
                    videoCount: videos.length,
                    isMobile: isMobile,
                    onPlayAll: () => _playFromIndex(context, ref, videos, 0),
                    onShuffle: () => _shufflePlay(context, ref, videos),
                  );
                }

                final video = videos[index - 1];
                final i = index - 1;
                return SongTile(
                  videoId: video.videoId,
                  title: video.name,
                  artist: video.artist.name,
                  artistId: video.artist.artistId,
                  thumbnailUrl:
                      video.thumbnails.isNotEmpty
                          ? video.thumbnails.last.url
                          : null,
                  duration: video.duration,
                  playCount: video.viewCount,
                  isVideo: true,
                  isExplicit: video.isExplicit,
                  onTap: () => _playFromIndex(context, ref, videos, i),
                );
              },
            ),
          );

          if (!isWide && isMobile) return list;

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
    ref.read(actionFeedbackProvider.notifier).report(l10n.playAll);
    try {
      await ref
          .read(playerStateProvider.notifier)
          .playPlaylist(videos, startIndex: startIndex);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToPlay(e.toString()))),
        );
      }
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToPlay(e.toString()))),
        );
      }
    }
  }
}

class _VideosHeader extends StatelessWidget {
  final int videoCount;
  final bool isMobile;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

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
