import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/album/providers/album_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';
import 'hover_play_button.dart';

enum ReleaseType { album, single, ep }

class ReleaseCard extends ConsumerStatefulWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final String? artistId;
  final ReleaseType type;
  final String? heroTag;
  final double cardWidth;
  final String? badgeText;
  final bool showArtist;

  const ReleaseCard({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    this.artistId,
    this.type = ReleaseType.album,
    this.heroTag,
    this.cardWidth = 150,
    this.badgeText,
    this.showArtist = false,
  });

  @override
  ConsumerState<ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends ConsumerState<ReleaseCard> {
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
          .report('Failed to play release: $e');
    }
  }

  String _typeLabel(BuildContext context) {
    switch (widget.type) {
      case ReleaseType.album:
        return AppLocalizations.of(context)!.albums;
      case ReleaseType.single:
        return AppLocalizations.of(context)!.singles;
      case ReleaseType.ep:
        return 'EP';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag = widget.heroTag ?? 'album_art_${widget.albumId}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap:
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
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: tag,
                    child: ThumbnailWidget(
                      imageUrl: widget.thumbnailUrl,
                      size: widget.cardWidth,
                      shape: ThumbnailShape.rounded,
                    ),
                  ),
                  if (widget.badgeText != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.badgeText!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: HoverPlayButton(isVisible: _isHovered, onTap: _play),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (widget.showArtist) widget.artist,
                  if (!widget.showArtist) _typeLabel(context),
                  if (widget.year != null) widget.year.toString(),
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
