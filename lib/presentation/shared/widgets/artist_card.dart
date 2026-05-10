import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'thumbnail_widget.dart';

class ArtistCard extends StatelessWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;

  const ArtistCard({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/artist/$artistId'),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 120,
              shape: ThumbnailShape.circle,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
