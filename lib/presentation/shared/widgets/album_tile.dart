import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'thumbnail_widget.dart';

class AlbumTile extends StatelessWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;

  const AlbumTile({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
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
        [artist, if (year != null) '$year'].join(' · '),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/album/$albumId'),
    );
  }
}
