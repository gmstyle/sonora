import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class SongTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;

  const SongTile({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
    this.isVideo = false,
    this.albumName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Stack(
        children: [
          ThumbnailWidget(imageUrl: thumbnailUrl, size: 48, shape: ThumbnailShape.rounded),
          if (isVideo)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'MV',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(
        [artist, if (albumName != null) albumName].join(' · '),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: duration != null
          ? Text(
              '${(duration! ~/ 60)}:${(duration! % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: () => ref.read(playerStateProvider.notifier).playVideoId(videoId),
      onLongPress: () => ContextMenuSheet.show(
        context,
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        albumName: albumName,
      ),
    );
  }
}
