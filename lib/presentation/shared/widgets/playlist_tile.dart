import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class PlaylistTile extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String artist;
  final String? thumbnailUrl;

  const PlaylistTile({
    super.key,
    required this.playlistId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
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
      subtitle: Text('$artist · Playlist', overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/playlist/$playlistId'),
      onLongPress:
          () => ContextMenuSheet.showForPlaylist(
            context,
            playlistId: playlistId,
            name: name,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
          ),
    );
  }
}
