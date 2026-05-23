import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import 'thumbnail_widget.dart';

class ArtistTile extends StatelessWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;

  const ArtistTile({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: 48,
        shape: ThumbnailShape.circle,
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(AppLocalizations.of(context)!.unknownArtist),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/artist/$artistId'),
    );
  }
}
