import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/tv/widgets/tv_focusable.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class PlaylistTile extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String artist;
  final String? thumbnailUrl;

  const PlaylistTile({
    super.key,
    required this.playlistId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => context.push('/playlist/$playlistId');
    void openMenu() {
      ContextMenuSheet.showForPlaylist(
        context,
        playlistId: playlistId,
        name: name,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
      );
    }

    return MaybeTvFocusable(
      debugLabel: 'playlist-tile:$playlistId',
      onSelect: open,
      onLongSelect: openMenu,
      child: ListTile(
        leading: ThumbnailWidget(
          imageUrl: thumbnailUrl,
          size: 48,
          shape: ThumbnailShape.rounded,
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
        subtitle: Text('$artist · Playlist', overflow: TextOverflow.ellipsis),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: open,
        onLongPress: openMenu,
      ),
    );
  }
}
