import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class PlaylistCard extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;

  const PlaylistCard({
    super.key,
    required this.playlistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/playlist/$playlistId'),
      onLongPress:
          () => ContextMenuSheet.showForPlaylist(
            context,
            playlistId: playlistId,
            name: name,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
          ),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 150,
              shape: ThumbnailShape.rounded,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (artist != null) ...[
              const SizedBox(height: 2),
              Text(
                artist!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
