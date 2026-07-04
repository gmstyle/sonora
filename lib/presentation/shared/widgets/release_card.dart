import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';

enum ReleaseType { album, single, ep }

class ReleaseCard extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;
  final ReleaseType type;
  final String? heroTag;

  const ReleaseCard({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    this.artistId,
    this.type = ReleaseType.album,
    this.heroTag,
  });

  String _typeLabel(BuildContext context) {
    switch (type) {
      case ReleaseType.album:
        return AppLocalizations.of(context)!.albums;
      case ReleaseType.single:
        return AppLocalizations.of(context)!.singles;
      case ReleaseType.ep:
        return 'EP';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag = heroTag ?? 'album_art_$albumId';

    return ScaleButton(
      onTap:
          () => context.push(
            '/album/$albumId?heroTag=${Uri.encodeComponent(tag)}',
          ),
      onLongPress:
          () => ContextMenuSheet.showForAlbum(
            context,
            albumId: albumId,
            name: name,
            artist: artist,
            artistId: artistId,
            thumbnailUrl: thumbnailUrl,
            year: year,
          ),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: tag,
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: 150,
                shape: ThumbnailShape.rounded,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                _typeLabel(context),
                if (year != null) year.toString(),
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
