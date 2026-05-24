import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/stat_format.dart';
import 'thumbnail_widget.dart';

class ArtistCard extends StatelessWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? monthlyListeners;

  const ArtistCard({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
  });

  @override
  Widget build(BuildContext context) {
    final listeners = monthlyListeners != null && monthlyListeners!.isNotEmpty
        ? stripYtLabel(monthlyListeners)
        : null;
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
            if (listeners != null) ...[
              const SizedBox(height: 2),
              Text(
                listeners,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
