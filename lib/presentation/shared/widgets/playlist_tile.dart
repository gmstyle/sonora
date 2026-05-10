import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'thumbnail_widget.dart';

class PlaylistTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListTile(
      leading: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: 48,
        shape: ThumbnailShape.rounded,
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$artist · Playlist',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/playlist/$playlistId'),
    );
  }
}
