import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class AlbumCard extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;

  const AlbumCard({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    this.artistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/album/$albumId'),
      onLongPress:
          () => ContextMenuSheet.showForAlbum(
            context,
            albumId: albumId,
            name: name,
            artist: artist,
            artistId: artistId,
            thumbnailUrl: thumbnailUrl,
            year: year,
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
            const SizedBox(height: 2),
            Text(
              artist,
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
