import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum ThumbnailShape { square, circle, rounded }

class ThumbnailWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final ThumbnailShape shape;
  final double? borderRadius;

  const ThumbnailWidget({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.shape = ThumbnailShape.square,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ??
        switch (shape) {
          ThumbnailShape.square => 0.0,
          ThumbnailShape.circle => size / 2,
          ThumbnailShape.rounded => 8.0,
        };

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveBorderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, _, _) => Icon(
                  Icons.music_note,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
