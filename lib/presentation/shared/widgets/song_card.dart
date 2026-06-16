import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sonora/core/extensions/duration_ext.dart';
import 'package:sonora/core/extensions/stat_format.dart';
import '../../providers/player_provider.dart';
import '../../providers/download_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';
import 'video_badge.dart';

class SongCard extends ConsumerStatefulWidget {
  final String videoId;
  final String? thumbnailUrl;
  final String title;
  final String artist;
  final int? duration;
  final String? playCount;
  final String? artistId;
  final String? albumId;
  final double cardWidth;
  final bool isVideo;

  const SongCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.title,
    required this.artist,
    this.duration,
    this.playCount,
    this.artistId,
    this.albumId,
    this.cardWidth = 150,
    this.isVideo = false,
  });

  @override
  ConsumerState<SongCard> createState() => _SongCardState();
}

class _SongCardState extends ConsumerState<SongCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final statLabel =
        widget.playCount != null && widget.playCount!.isNotEmpty
            ? stripYtLabel(widget.playCount)
            : null;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(widget.videoId);

    final thumbRatio = widget.cardWidth / 150;
    final thumbSize = widget.cardWidth;
    final height = (statLabel != null ? 236 : 220) * thumbRatio;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap:
            () => ref
                .read(playerStateProvider.notifier)
                .playVideoId(widget.videoId, isVideo: widget.isVideo),
        onLongPress:
            () => ContextMenuSheet.showForSong(
              context,
              videoId: widget.videoId,
              title: widget.title,
              artist: widget.artist,
              thumbnailUrl: widget.thumbnailUrl,
              duration: widget.duration,
              isVideo: widget.isVideo,
              artistId: widget.artistId,
              albumId: widget.albumId,
            ),
        child: SizedBox(
          width: widget.cardWidth,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ThumbnailWidget(
                    imageUrl: widget.thumbnailUrl,
                    size: thumbSize,
                    shape: ThumbnailShape.rounded,
                  ),
                  if (widget.duration != null && !_isHovered)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Duration(seconds: widget.duration!).format(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  if (isDownloaded)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.checkCircle,
                          size: 12,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  if (widget.isVideo)
                    Positioned(
                      bottom: 6,
                      left: isDownloaded ? 28 : 6,
                      child: const VideoBadge(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        borderRadius: 4,
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: ScaleButton(
                        onTap:
                            () => ref
                                .read(playerStateProvider.notifier)
                                .playVideoId(
                                  widget.videoId,
                                  isVideo: widget.isVideo,
                                ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            LucideIcons.play,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                [widget.artist, if (statLabel != null) statLabel].join(' · '),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
