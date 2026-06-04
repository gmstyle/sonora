import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PlaylistCoverCollage extends StatelessWidget {
  final List<String?> thumbnailUrls;
  final double borderRadius;

  const PlaylistCoverCollage({
    super.key,
    required this.thumbnailUrls,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final urls = thumbnailUrls.where((u) => u != null).take(3).toList();
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: switch (urls.length) {
        0 => _placeholder(cs),
        1 => _CachedImage(url: urls[0]!, fit: BoxFit.cover),
        2 => Row(
          children: [
            Expanded(
              flex: 2,
              child: _CachedImage(url: urls[0]!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: _CachedImage(url: urls[1]!, fit: BoxFit.cover),
            ),
          ],
        ),
        _ => Row(
          children: [
            Expanded(
              flex: 2,
              child: _CachedImage(url: urls[0]!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(
                    child: _CachedImage(url: urls[1]!, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _CachedImage(url: urls[2]!, fit: BoxFit.cover),
                  ),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
    color: cs.surfaceContainerHighest,
    child: Center(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final iconSize = (constraints.maxWidth * 0.35).clamp(40.0, 120.0);
          return Icon(
            LucideIcons.listVideo,
            size: iconSize,
            color: cs.onSurfaceVariant,
          );
        },
      ),
    ),
  );
}

class _CachedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _CachedImage({required this.url, required this.fit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => Container(color: cs.surfaceContainerHighest),
      errorWidget:
          (_, _, _) => Container(
            color: cs.surfaceContainerHighest,
            child: Icon(LucideIcons.music, color: cs.onSurfaceVariant),
          ),
    );
  }
}
