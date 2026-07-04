import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/playlist/providers/playlist_provider.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/library/widgets/playlist_detail_view.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'thumbnail_widget.dart';
import 'playlist_cover_collage.dart';
import 'hover_play_button.dart';

class PlaylistCard extends ConsumerStatefulWidget {
  final String? playlistId;
  final int? localPlaylistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;
  final double cardWidth;
  final String? heroTag;
  final LocalPlaylistModel? localPlaylist;

  const PlaylistCard({
    super.key,
    this.playlistId,
    this.localPlaylistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
    this.cardWidth = 150,
    this.heroTag,
    this.localPlaylist,
  }) : assert(playlistId != null || localPlaylistId != null, 'Must provide either playlistId or localPlaylistId');

  @override
  ConsumerState<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends ConsumerState<PlaylistCard> {
  bool _isHovered = false;

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context)!;
    ref.read(actionFeedbackProvider.notifier).report(l10n.playingPlaylist(widget.name));
    try {
      final player = ref.read(playerStateProvider.notifier);
      if (widget.localPlaylistId != null) {
        final entries = await ref.read(
          playlistEntriesProvider(widget.localPlaylistId!).future,
        );
        final items = await ref
            .read(libraryNotifierProvider.notifier)
            .buildLocalPlaylistItems(entries, playIndex: 0);
        await player.playNow(items, initialIndex: 0);
      } else if (widget.playlistId != null) {
        final songs = await ref.read(
          playlistVideosProvider(widget.playlistId!).future,
        );
        await player.playPlaylist(songs, startIndex: 0);
      }
    } catch (e) {
      if (!mounted) return;
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToPlayPlaylist(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = widget.localPlaylistId != null;
    final tag = widget.heroTag ?? (isLocal ? 'local_playlist_art_${widget.localPlaylistId}' : 'playlist_art_${widget.playlistId}');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap: () {
          if (isLocal) {
            final playlistModel = widget.localPlaylist ?? LocalPlaylistModel(
              id: widget.localPlaylistId!,
              name: widget.name,
              description: widget.artist,
              createdAt: DateTime.now(),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => PlaylistDetailView(
                      playlist: playlistModel,
                      onUpdated: () {
                        ref.invalidate(playlistsProvider);
                      },
                    ),
              ),
            );
          } else {
            context.push(
              '/playlist/${widget.playlistId}?heroTag=${Uri.encodeComponent(tag)}',
            );
          }
        },
        onLongPress: () {
          if (isLocal) {
            final playlistModel = widget.localPlaylist ?? LocalPlaylistModel(
              id: widget.localPlaylistId!,
              name: widget.name,
              description: widget.artist,
              createdAt: DateTime.now(),
            );
            ContextMenuSheet.showForCustomPlaylist(
              context,
              playlist: playlistModel,
              onUpdated: () => ref.invalidate(playlistsProvider),
            );
          } else {
            ContextMenuSheet.showForPlaylist(
              context,
              playlistId: widget.playlistId!,
              name: widget.name,
              artist: widget.artist,
              thumbnailUrl: widget.thumbnailUrl,
            );
          }
        },
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: tag,
                    child: isLocal
                        ? _LocalPlaylistCoverBuilder(
                            playlistId: widget.localPlaylistId!,
                            size: widget.cardWidth,
                          )
                        : ThumbnailWidget(
                            imageUrl: widget.thumbnailUrl,
                            size: widget.cardWidth,
                            shape: ThumbnailShape.rounded,
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: HoverPlayButton(
                      isVisible: _isHovered,
                      onTap: _play,
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
              if (widget.artist != null && widget.artist!.isNotEmpty) ...[
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

class _LocalPlaylistCoverBuilder extends ConsumerWidget {
  final int playlistId;
  final double size;

  const _LocalPlaylistCoverBuilder({required this.playlistId, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(playlistEntriesProvider(playlistId));

    return entriesAsync.when(
      loading: () => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      error: (_, _) => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      data: (entries) {
        final urls =
            entries
                .map((e) => e.thumbnailUrl)
                .where((url) => url != null && url.isNotEmpty)
                .cast<String>()
                .toList();

        return SizedBox(
          width: size,
          height: size,
          child: PlaylistCoverCollage(thumbnailUrls: urls, borderRadius: 8),
        );
      },
    );
  }
}
