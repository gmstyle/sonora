import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/album/providers/album_provider.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';

class AlbumCard extends ConsumerStatefulWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;
  final double cardWidth;

  const AlbumCard({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    this.artistId,
    this.cardWidth = 150,
  });

  @override
  ConsumerState<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends ConsumerState<AlbumCard> {
  bool _isHovered = false;

  Future<void> _play() async {
    ref.read(actionFeedbackProvider.notifier).report('Playing ${widget.name}…');
    try {
      final album = await ref.read(albumProvider(widget.albumId).future);
      final useCase = ref.read(playAlbumUseCaseProvider);
      final player = ref.read(playerStateProvider.notifier);
      final items = await useCase.execute(album.songs);
      if (items.isNotEmpty) {
        await player.playNow(items, initialIndex: 0);
      }
    } catch (e) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report('Failed to play album: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap: () => context.push('/album/${widget.albumId}'),
        onLongPress:
            () => ContextMenuSheet.showForAlbum(
              context,
              albumId: widget.albumId,
              name: widget.name,
              artist: widget.artist,
              artistId: widget.artistId,
              thumbnailUrl: widget.thumbnailUrl,
              year: widget.year,
            ),
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'album_art_${widget.albumId}',
                    child: ThumbnailWidget(
                      imageUrl: widget.thumbnailUrl,
                      size: widget.cardWidth,
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
              const SizedBox(height: 2),
              Text(
                widget.artist,
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
