import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/extensions/duration_ext.dart';
import '../../../core/extensions/stat_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import '../../providers/download_provider.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';
import 'video_badge.dart';
import 'explicit_badge.dart';

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
  final bool isExplicit;
  final int? index;
  final Widget? leadingOverride;
  final List<Widget>? trailingActions;
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
    this.isExplicit = false,
    this.index,
    this.leadingOverride,
    this.trailingActions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statLabel = _formatStat();
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

    return ListTile(
      leading: leadingOverride ?? _buildLeading(context, isDownloaded),
      title: Text.rich(
        TextSpan(
          children: [
            if (isExplicit)
              const WidgetSpan(
                child: Padding(
                  padding: EdgeInsets.only(right: 6.0),
                  child: ExplicitBadge(),
                ),
                alignment: PlaceholderAlignment.middle,
              ),
            TextSpan(text: title),
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        [
          artist,
          if (albumName != null) albumName,
          if (statLabel != null) statLabel,
        ].join(' · '),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _buildTrailing(context),
      onTap:
          onTap ??
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(videoId, isVideo: isVideo, isExplicit: isExplicit),
      onLongPress:
          () => ContextMenuSheet.showForSong(
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
            isExplicit: isExplicit,
          ),
    );
  }

  Widget _buildLeading(BuildContext context, bool isDownloaded) {
    final thumbnail = Stack(
      children: [
        ThumbnailWidget(
          imageUrl: thumbnailUrl,
          size: 48,
          shape: ThumbnailShape.rounded,
        ),
        if (isVideo)
          Positioned(
            bottom: 0,
            right: isDownloaded ? null : 0,
            left: isDownloaded ? 0 : null,
            child: const VideoBadge(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              borderRadius: 3,
            ),
          ),
        if (isDownloaded)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.checkCircle,
                size: 10,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );

    if (index != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          thumbnail,
        ],
      );
    }

    return thumbnail;
  }

  String? _formatStat() {
    if (playCount != null && playCount!.isNotEmpty) {
      return stripYtLabel(playCount);
    }
    if (viewCount != null) return viewCount!.toCompact();
    return null;
  }

  Widget? _buildTrailing(BuildContext context) {
    final hasDuration = duration != null;
    final hasActions = trailingActions != null && trailingActions!.isNotEmpty;

    if (!hasDuration && !hasActions) return null;

    final durationWidget =
        hasDuration
            ? Text(
              Duration(seconds: duration!).format(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
            : null;

    if (hasActions) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (durationWidget != null) ...[
            durationWidget,
            const SizedBox(width: 8),
          ],
          ...trailingActions!,
        ],
      );
    }

    return durationWidget;
  }
}
