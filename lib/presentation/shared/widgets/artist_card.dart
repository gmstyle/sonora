import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../l10n/app_localizations.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';

class ArtistCard extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? monthlyListeners;
  final double cardWidth;
  final String? heroTag;
  final VoidCallback? onTap;

  const ArtistCard({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
    this.cardWidth = 120,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle =
        monthlyListeners != null && monthlyListeners!.isNotEmpty
            ? stripYtLabel(monthlyListeners)
            : AppLocalizations.of(
              context,
            )!.artists; // Fallback "Artisti" / "Artists"

    final thumbSize = (cardWidth * 110 / 120).roundToDouble();
    final tag = heroTag ?? 'artist_art_$artistId';

    return ScaleButton(
      onTap:
          onTap ??
          () => context.push(
            '/artist/$artistId?heroTag=${Uri.encodeComponent(tag)}',
          ),
      onLongPress:
          () => ContextMenuSheet.showForArtist(
            context,
            artistId: artistId,
            name: name,
            thumbnailUrl: thumbnailUrl,
            monthlyListeners: monthlyListeners,
          ),
      child: SizedBox(
        width: cardWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textBlock = <Widget>[
              const SizedBox(height: 10),
              Text(
                name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle ?? '',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ];

            // Grid / carousel cells pass a max height; shrink the avatar
            // so name + subtitle still fit without overflowing.
            // AspectRatio sizes to the fitted square (not the flex max), so
            // Flexible(loose) does not leave a gap above the title.
            if (constraints.hasBoundedHeight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: thumbSize,
                        maxHeight: thumbSize,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, coverConstraints) {
                            return Hero(
                              tag: tag,
                              child: ThumbnailWidget(
                                imageUrl: thumbnailUrl,
                                size: coverConstraints.maxWidth,
                                shape: ThumbnailShape.circle,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  ...textBlock,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: tag,
                  child: ThumbnailWidget(
                    imageUrl: thumbnailUrl,
                    size: thumbSize,
                    shape: ThumbnailShape.circle,
                  ),
                ),
                ...textBlock,
              ],
            );
          },
        ),
      ),
    );
  }
}
