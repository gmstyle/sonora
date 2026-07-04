import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sonora/core/extensions/duration_ext.dart';
import 'package:sonora/core/extensions/stat_format.dart';
import '../../providers/player_provider.dart';
import '../../providers/download_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';
import 'video_badge.dart';
import 'explicit_badge.dart';

class SongCard extends ConsumerWidget {
  final String videoId;
  final String? thumbnailUrl;
  final String title;
  final String artist;
  final int? duration;
  final String? playCount;
  final String? artistId;
  final String? albumId;
  final double cardWidth;
  final bool isVideo;
  final bool isExplicit;

  const SongCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.title,
    required this.artist,
    this.duration,
    this.playCount,
    this.artistId,
    this.albumId,
    this.cardWidth = 150,
    this.isVideo = false,
    this.isExplicit = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statLabel =
        playCount != null && playCount!.isNotEmpty
            ? stripYtLabel(playCount)
            : null;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

    final thumbRatio = cardWidth / 150;
    final thumbSize = cardWidth;
    final height = (statLabel != null ? 236 : 220) * thumbRatio;

    return ScaleButton(
      onTap:
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(videoId, isVideo: isVideo, isExplicit: isExplicit),
      onLongPress:
          () => ContextMenuSheet.showForSong(
            context,
            videoId: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            isVideo: isVideo,
            artistId: artistId,
            albumId: albumId,
            playCount: playCount,
            isExplicit: isExplicit,
          ),
      child: SizedBox(
        width: cardWidth,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: thumbSize,
                  shape: ThumbnailShape.rounded,
                ),
                if (duration != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Duration(seconds: duration!).format(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                if (isDownloaded)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.checkCircle,
                        size: 12,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                if (isVideo)
                  Positioned(
                    bottom: 6,
                    left: isDownloaded ? 28 : 6,
                    child: const VideoBadge(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      borderRadius: 4,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  if (isExplicit)
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.only(right: 6.0),
                        child: ExplicitBadge(),
                      ),
                      alignment: PlaceholderAlignment.middle,
                    ),
                  TextSpan(text: title),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [artist, if (statLabel != null) statLabel].join(' · '),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
