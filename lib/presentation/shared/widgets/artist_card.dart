import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../l10n/app_localizations.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'shelf_card_layout.dart';
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
            : AppLocalizations.of(context)!.artists;

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
      child: ShelfCardLayout(
        cardWidth: cardWidth,
        maxCoverSize: thumbSize,
        crossAxisAlignment: CrossAxisAlignment.center,
        coverBuilder:
            (size) => Hero(
              tag: tag,
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: size,
                shape: ThumbnailShape.circle,
              ),
            ),
        textBlock: [
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
        ],
      ),
    );
  }
}
