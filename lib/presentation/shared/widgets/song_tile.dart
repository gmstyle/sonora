import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/stat_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class SongTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final String? playCount;
  final int? viewCount;
  final VoidCallback? onTap;

  const SongTile({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
    this.isVideo = false,
    this.albumName,
    this.artistId,
    this.albumId,
    this.playCount,
    this.viewCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statLabel = _formatStat();
    return ListTile(
      leading: Stack(
        children: [
          ThumbnailWidget(imageUrl: thumbnailUrl, size: 48, shape: ThumbnailShape.rounded),
          if (isVideo)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  AppLocalizations.of(context)!.mv,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(
        [
          artist,
          if (albumName != null) albumName,
          if (statLabel != null) statLabel,
        ].join(' · '),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: duration != null
          ? Text(
              '${(duration! ~/ 60)}:${(duration! % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: onTap ?? () => ref.read(playerStateProvider.notifier).playVideoId(videoId),
      onLongPress: () => ContextMenuSheet.show(
        context,
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        albumName: albumName,
        artistId: artistId,
        albumId: albumId,
        playCount: playCount,
        viewCount: viewCount,
      ),
    );
  }

  String? _formatStat() {
    if (playCount != null && playCount!.isNotEmpty) return stripYtLabel(playCount);
    if (viewCount != null) return viewCount!.toCompact();
    return null;
  }
}
