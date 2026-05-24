import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class AlbumTile extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;

  const AlbumTile({
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
    return ListTile(
      leading: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: 48,
        shape: ThumbnailShape.rounded,
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [artist, if (year != null) '$year'].join(' · '),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
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
    );
  }
}
