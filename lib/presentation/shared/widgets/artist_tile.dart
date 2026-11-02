import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/stat_format.dart';
import '../../features/tv/widgets/tv_focusable.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class ArtistTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle =
        monthlyListeners != null && monthlyListeners!.isNotEmpty
            ? stripYtLabel(monthlyListeners) ??
                AppLocalizations.of(context)!.artists
            : AppLocalizations.of(context)!.artists;

    void open() => context.push('/artist/$artistId');
    void openMenu() {
      ContextMenuSheet.showForArtist(
        context,
        artistId: artistId,
        name: name,
        thumbnailUrl: thumbnailUrl,
        monthlyListeners: monthlyListeners,
      );
    }

    return MaybeTvFocusable(
      debugLabel: 'artist-tile:$artistId',
      onSelect: open,
      onLongSelect: openMenu,
      child: ListTile(
        leading: ThumbnailWidget(
          imageUrl: thumbnailUrl,
          size: 48,
          shape: ThumbnailShape.circle,
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: open,
        onLongPress: openMenu,
      ),
    );
  }
}
