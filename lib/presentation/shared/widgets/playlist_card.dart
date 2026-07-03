import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/playlist/providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';

class PlaylistCard extends ConsumerStatefulWidget {
  final String playlistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;

  const PlaylistCard({
    super.key,
    required this.playlistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends ConsumerState<PlaylistCard> {
  bool _isHovered = false;

  Future<void> _play() async {
    ref.read(actionFeedbackProvider.notifier).report('Playing ${widget.name}…');
    try {
      final songs = await ref.read(
        playlistVideosProvider(widget.playlistId).future,
      );
      final player = ref.read(playerStateProvider.notifier);
      await player.playPlaylist(songs, startIndex: 0);
    } catch (e) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report('Failed to play playlist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap: () => context.push('/playlist/${widget.playlistId}'),
        onLongPress:
            () => ContextMenuSheet.showForPlaylist(
              context,
              playlistId: widget.playlistId,
              name: widget.name,
              artist: widget.artist,
              thumbnailUrl: widget.thumbnailUrl,
            ),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'playlist_art_${widget.playlistId}',
                    child: ThumbnailWidget(
                      imageUrl: widget.thumbnailUrl,
                      size: 150,
                      shape: ThumbnailShape.rounded,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: ScaleButton(
                        onTap: _play,
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
              const SizedBox(height: 8),
              Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (widget.artist != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.artist!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
