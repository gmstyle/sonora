import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/album/providers/album_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'shelf_card_layout.dart';
import 'thumbnail_widget.dart';
import 'hover_play_button.dart';

class AlbumCard extends ConsumerStatefulWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;
  final double cardWidth;
  final String? heroTag;
  final VoidCallback? onTap;

  const AlbumCard({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    this.artistId,
    this.cardWidth = 150,
    this.heroTag,
    this.onTap,
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
      final player = ref.read(playerStateProvider.notifier);
      await player.playAlbum(album.songs, startIndex: 0);
    } catch (e) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report('Failed to play album: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.heroTag ?? 'album_art_${widget.albumId}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap:
            widget.onTap ??
            () => context.push(
              '/album/${widget.albumId}?heroTag=${Uri.encodeComponent(tag)}',
            ),
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
        child: ShelfCardLayout(
          cardWidth: widget.cardWidth,
          coverBuilder:
              (size) => Stack(
                children: [
                  Hero(
                    tag: tag,
                    child: ThumbnailWidget(
                      imageUrl: widget.thumbnailUrl,
                      size: size,
                      shape: ThumbnailShape.rounded,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: HoverPlayButton(isVisible: _isHovered, onTap: _play),
                  ),
                ],
              ),
          textBlock: [
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
    );
  }
}
