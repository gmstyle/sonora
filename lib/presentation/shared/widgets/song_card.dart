import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora/core/extensions/duration_ext.dart';
import 'package:sonora/core/extensions/stat_format.dart';
import '../../providers/player_provider.dart';
import 'thumbnail_widget.dart';

class SongCard extends ConsumerWidget {
  final String videoId;
  final String? thumbnailUrl;
  final String title;
  final String artist;
  final int? duration;
  final String? playCount;

  const SongCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.title,
    required this.artist,
    this.duration,
    this.playCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statLabel = playCount != null && playCount!.isNotEmpty
        ? stripYtLabel(playCount)
        : null;
    return InkWell(
      onTap: () => ref.read(playerStateProvider.notifier).playVideoId(videoId),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 150,
        height: statLabel != null ? 236 : 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 150,
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
                        Duration(seconds: duration!).toMinutesSeconds(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              [artist, if (statLabel != null) statLabel].join(' · '),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
