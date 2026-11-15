import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/utils/artists_utils.dart';
import '../../../../../core/utils/playable_tracks.dart';
import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/play_album_use_case_provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/detail_actions_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../album/providers/album_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_track_row.dart';

class TvAlbumScreen extends ConsumerWidget {
  final String albumId;

  const TvAlbumScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(albumProvider(albumId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadAlbum,
          onRetry: () => ref.invalidate(albumProvider(albumId)),
        ),
      ),
      data: (album) => _TvAlbumBody(album: album),
    );
  }
}

class _TvAlbumBody extends ConsumerStatefulWidget {
  final AlbumFull album;

  const _TvAlbumBody({required this.album});

  @override
  ConsumerState<_TvAlbumBody> createState() => _TvAlbumBodyState();
}

class _TvAlbumBodyState extends ConsumerState<_TvAlbumBody> {
  final FocusNode _playAllFocus = FocusNode(debugLabel: 'tvAlbumPlayAll');

  @override
  void dispose() {
    _playAllFocus.dispose();
    super.dispose();
  }

  String? _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final offline = ref.watch(isOfflineProvider);
    final liked = ref.watch(likedAlbumProvider(album.albumId)).asData?.value;
    final playingVideoId = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.id),
    );
    final playable = playableSongs(album.songs);
    final art = album.thumbnails.isNotEmpty ? album.thumbnails.last.url : null;
    final metaParts = <String>[
      l10n.entityKindAlbum,
      if (album.year != null) '${album.year}',
      l10n.catalogSongCount(album.songs.length),
    ];

    return Scaffold(
      backgroundColor: TvColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Split 40%): Centered Artwork, Meta & Action Stack
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TvFocusable(
                        onSelect: () => context.pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TvColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.chevronLeft,
                                size: 16,
                                color: TvColors.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.askIntroBack,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: TvColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Large 168dp Centered Artwork
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ThumbnailWidget(
                        imageUrl: art,
                        size: 164,
                        shape: ThumbnailShape.rounded,
                        borderRadius: 16,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: TvColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayArtists(album.artists),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metaParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: TvColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action Buttons Stack (Remote Ergonomics)
                    SizedBox(
                      width: 224,
                      child: Column(
                        children: [
                          TvFocusable(
                            focusNode: _playAllFocus,
                            autofocus: true,
                            onSelect: playable.isEmpty
                                ? null
                                : () => ref
                                      .read(playerStateProvider.notifier)
                                      .playAlbum(playable, startIndex: 0),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.play,
                                    size: 16,
                                    color: colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.playAll,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TvFocusable(
                            onSelect: playable.isEmpty
                                ? null
                                : () {
                                    final shuffled = List<SongDetailed>.from(
                                      playable,
                                    )..shuffle();
                                    ref
                                        .read(playerStateProvider.notifier)
                                        .playAlbum(shuffled, startIndex: 0);
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TvColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.shuffle,
                                    size: 15,
                                    color: TvColors.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.shufflePlay,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: TvColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TvFocusable(
                                  onSelect: () {
                                    ref
                                        .read(libraryNotifierProvider.notifier)
                                        .toggleLikedAlbum(
                                          LikedAlbumModel(
                                            albumId: album.albumId,
                                            name: album.name,
                                            artistName: displayArtists(
                                              album.artists,
                                            ),
                                            artistId: primaryArtistId(
                                              album.artists,
                                            ),
                                            thumbnailUrl: art,
                                            year: album.year,
                                            addedAt: DateTime.now(),
                                          ),
                                        );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: liked != null
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.16,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: liked != null
                                            ? colorScheme.primary.withValues(
                                                alpha: 0.4,
                                              )
                                            : TvColors.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          liked != null
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 15,
                                          color: liked != null
                                              ? colorScheme.primary
                                              : TvColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.like,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: liked != null
                                                    ? colorScheme.primary
                                                    : TvColors.textPrimary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TvFocusable(
                                onSelect: playable.isEmpty
                                    ? null
                                    : () => _addToQueue(context, ref, playable),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: const Icon(
                                    LucideIcons.listMusic,
                                    size: 17,
                                    color: TvColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TvFocusable(
                                onSelect: () => ContextMenuSheet.showForAlbum(
                                  context,
                                  albumId: album.albumId,
                                  name: album.name,
                                  artist: displayArtists(album.artists),
                                  artistId: primaryArtistId(album.artists),
                                  thumbnailUrl: art,
                                  year: album.year,
                                  omitActionIds: {
                                    DetailActionId.play,
                                    DetailActionId.shuffle,
                                    DetailActionId.queue,
                                    DetailActionId.save,
                                    DetailActionId.share,
                                    if (offline) DetailActionId.download,
                                    if (offline) DetailActionId.radio,
                                  },
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: const Icon(
                                    LucideIcons.ellipsisVertical,
                                    size: 17,
                                    color: TvColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // Right Column (Split 60%): High-Contrast Scrollable Tracklist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n.songs.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: TvColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.duration.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: TvColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: TvColors.border),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: album.songs.length,
                        itemBuilder: (context, index) {
                          final song = album.songs[index];
                          return TvTrackRow(
                            index: index,
                            title: song.name,
                            subtitle: displayArtists(song.artists),
                            duration: _fmtDuration(song.duration),
                            isExplicit: song.isExplicit,
                            isPlaying: playingVideoId == song.videoId,
                            enabled: song.isPlayable,
                            onLeftAtEdge: () => _playAllFocus.requestFocus(),
                            onSelect: () {
                              final start = playable.indexWhere(
                                (s) => s.videoId == song.videoId,
                              );
                              if (start < 0) return;
                              ref
                                  .read(playerStateProvider.notifier)
                                  .playAlbum(playable, startIndex: start);
                            },
                            onLongSelect: () => ContextMenuSheet.showForSong(
                              context,
                              videoId: song.videoId,
                              title: song.name,
                              artist: displayArtists(song.artists),
                              artists: song.artists,
                              thumbnailUrl: song.thumbnails.isNotEmpty
                                  ? song.thumbnails.last.url
                                  : null,
                              isVideo: song.type == 'VIDEO',
                              isExplicit: song.isExplicit,
                              isPlayable: song.isPlayable,
                              albumId: album.albumId,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToQueue(
    BuildContext context,
    WidgetRef ref,
    List<SongDetailed> songs,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await ref
          .read(playAlbumUseCaseProvider)
          .execute(songs, playIndex: -1);
      if (items.isNotEmpty) {
        await ref.read(playerStateProvider.notifier).addAllToQueue(items);
      }
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add album to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
      }
    }
  }
}
