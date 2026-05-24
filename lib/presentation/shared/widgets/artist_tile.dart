import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/stat_format.dart';
import 'thumbnail_widget.dart';

class ArtistTile extends StatelessWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? monthlyListeners;

  const ArtistTile({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = monthlyListeners != null && monthlyListeners!.isNotEmpty
        ? stripYtLabel(monthlyListeners) ?? AppLocalizations.of(context)!.unknownArtist
        : AppLocalizations.of(context)!.unknownArtist;
    return ListTile(
      leading: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: 48,
        shape: ThumbnailShape.circle,
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/artist/$artistId'),
    );
  }
}
