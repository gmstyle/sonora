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

  const ArtistCard({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle =
        monthlyListeners != null && monthlyListeners!.isNotEmpty
            ? stripYtLabel(monthlyListeners)
            : AppLocalizations.of(
              context,
            )!.artists; // Fallback "Artisti" / "Artists"

    return ScaleButton(
      onTap: () => context.push('/artist/$artistId'),
      onLongPress:
          () => ContextMenuSheet.showForArtist(
            context,
            artistId: artistId,
            name: name,
            thumbnailUrl: thumbnailUrl,
            monthlyListeners: monthlyListeners,
          ),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'artist_art_$artistId',
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: 110,
                shape: ThumbnailShape.circle,
              ),
            ),
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
      ),
    );
  }
}
