import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/extensions/stat_format.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/models/library_models.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';
import '../../features/album/providers/album_provider.dart';
import '../../features/artist/providers/artist_provider.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/playlist/providers/playlist_provider.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/play_playlist_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import 'thumbnail_widget.dart';

import '../../features/library/widgets/create_playlist_dialog.dart';
import '../../features/library/widgets/playlist_detail_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Song data provider (lazy enrichment for context menu)
// ─────────────────────────────────────────────────────────────────────────────
// TODO: remove once all LikedSongModel rows in the local DB have
// non-null artistId/albumId (enrichment backfill completed).

final _songFullProvider = FutureProvider.family<SongFull, String>((
  ref,
  videoId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getSong(videoId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Public facade
// ─────────────────────────────────────────────────────────────────────────────

class ContextMenuSheet {
  ContextMenuSheet._();

  static Future<void> showForSong(
    BuildContext context, {
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    String? playCount,
    int? viewCount,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _SongContextMenuSheet(
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
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _SongContextMenuSheet(
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

  static Future<void> showForArtist(
    BuildContext context, {
    required String artistId,
    required String name,
    String? thumbnailUrl,
    String? monthlyListeners,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _ArtistContextMenuSheet(
                    artistId: artistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                    monthlyListeners: monthlyListeners,
                  ),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _ArtistContextMenuSheet(
            artistId: artistId,
            name: name,
            thumbnailUrl: thumbnailUrl,
            monthlyListeners: monthlyListeners,
          ),
    );
  }

  static Future<void> showForAlbum(
    BuildContext context, {
    required String albumId,
    required String name,
    required String artist,
    String? artistId,
    String? thumbnailUrl,
    int? year,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _AlbumContextMenuSheet(
                    albumId: albumId,
                    name: name,
                    artist: artist,
                    artistId: artistId,
                    thumbnailUrl: thumbnailUrl,
                    year: year,
                  ),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _AlbumContextMenuSheet(
            albumId: albumId,
            name: name,
            artist: artist,
            artistId: artistId,
            thumbnailUrl: thumbnailUrl,
            year: year,
          ),
    );
  }

  static Future<void> showForPlaylist(
    BuildContext context, {
    required String playlistId,
    required String name,
    String? artist,
    String? thumbnailUrl,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _PlaylistContextMenuSheet(
                    playlistId: playlistId,
                    name: name,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                  ),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _PlaylistContextMenuSheet(
            playlistId: playlistId,
            name: name,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
          ),
    );
  }

  static Future<void> showForCustomPlaylist(
    BuildContext context, {
    required LocalPlaylistModel playlist,
    required VoidCallback onUpdated,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _CustomPlaylistContextMenuSheet(
                    playlist: playlist,
                    onUpdated: onUpdated,
                  ),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _CustomPlaylistContextMenuSheet(
            playlist: playlist,
            onUpdated: onUpdated,
          ),
    );
  }

  static Future<void> showForNowPlaying(
    BuildContext context, {
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    bool isVideo = false,
    String? albumName,
    String? artistId,
    String? albumId,
    required void Function(String artistId) onGoToArtist,
    required void Function(String albumId) onGoToAlbum,
  }) {
    if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (_) => Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.hardEdge,
                  child: _NowPlayingContextMenuSheet(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    isVideo: isVideo,
                    albumName: albumName,
                    artistId: artistId,
                    albumId: albumId,
                    onGoToArtist: onGoToArtist,
                    onGoToAlbum: onGoToAlbum,
                  ),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => _NowPlayingContextMenuSheet(
            videoId: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            isVideo: isVideo,
            albumName: albumName,
            artistId: artistId,
            albumId: albumId,
            onGoToArtist: onGoToArtist,
            onGoToAlbum: onGoToAlbum,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Now‑playing context menu (full‑player top‑bar)
// ─────────────────────────────────────────────────────────────────────────────

class _NowPlayingContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final void Function(String artistId) onGoToArtist;
  final void Function(String albumId) onGoToAlbum;

  const _NowPlayingContextMenuSheet({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.isVideo = false,
    this.albumName,
    this.artistId,
    this.albumId,
    required this.onGoToArtist,
    required this.onGoToAlbum,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

    final hasExplicitIds = artistId != null || albumId != null;
    final songAsync = ref.watch(_songFullProvider(videoId));
    final resolvedArtistId =
        artistId ?? songAsync.asData?.value.artist.artistId;
    final resolvedAlbumId = albumId ?? songAsync.asData?.value.album?.albumId;
    final isLoadingFallback = !hasExplicitIds && songAsync.isLoading;

    ref.listen(_songFullProvider(videoId), (_, next) {
      if (next is AsyncData) {
        final data = next.value;
        if (data == null) return;
        final fullId = data.artist.artistId;
        final fullAlbumId = data.album?.albumId;
        if (fullId != null || fullAlbumId != null) {
          ref
              .read(libraryNotifierProvider.notifier)
              .updateLikedSongMetadata(
                videoId,
                artistId: fullId,
                albumId: fullAlbumId,
              );
        }
      }
    });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoadingFallback)
                    _LoadingTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                    ),
                  if (resolvedArtistId != null)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        Navigator.pop(context);
                        onGoToArtist(resolvedArtistId);
                      },
                    ),
                  if (isLoadingFallback)
                    _LoadingTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                    ),
                  if (resolvedAlbumId != null)
                    _ActionTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                      onTap: () {
                        Navigator.pop(context);
                        onGoToAlbum(resolvedAlbumId);
                      },
                    ),
                  _ActionTile(
                    icon: LucideIcons.radio,
                    label: AppLocalizations.of(context)!.startRadio,
                    onTap: () {
                      final useCase = ref.read(startRadioUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      final currentPlayer = player;
                      Navigator.pop(context);
                      _startSongRadio(useCase, currentPlayer, feedback);
                    },
                  ),
                  _ActionTile(
                    icon:
                        isDownloaded
                            ? LucideIcons.checkCircle
                            : LucideIcons.download,
                    label:
                        isDownloaded
                            ? AppLocalizations.of(context)!.downloaded
                            : AppLocalizations.of(context)!.download,
                    onTap: () {
                      Navigator.pop(context);
                      if (isDownloaded) {
                        showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.alreadyDownloaded,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.alreadyDownloadedConfirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      AppLocalizations.of(context)!.cancel,
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.continueAction,
                                    ),
                                  ),
                                ],
                              ),
                        ).then((proceed) {
                          if (proceed == true) {
                            ref
                                .read(activeDownloadsProvider.notifier)
                                .startDownload(
                                  videoId: videoId,
                                  title: title,
                                  artist: artist,
                                  thumbnailUrl: thumbnailUrl,
                                );
                          }
                        });
                      } else {
                        ref
                            .read(activeDownloadsProvider.notifier)
                            .startDownload(
                              videoId: videoId,
                              title: title,
                              artist: artist,
                              thumbnailUrl: thumbnailUrl,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.downloadStarted,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.plus,
                    label: AppLocalizations.of(context)!.addToPlaylist,
                    onTap: () {
                      Navigator.pop(context);
                      _showPlaylistPicker(
                        context,
                        ref,
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSongRadio(
    StartRadioUseCase useCase,
    PlayerNotifier currentPlayer,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final result = await useCase.execute(videoId);
      await currentPlayer.playNow([result.firstItem]);
      if (result.remaining.isNotEmpty) {
        final pendingItems = useCase.toPendingItems(result.remaining);
        currentPlayer.addAllToQueue(pendingItems);
      }
    } catch (e) {
      feedback.report('Failed to start radio: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Song context menu
// ─────────────────────────────────────────────────────────────────────────────

class _SongContextMenuSheet extends ConsumerWidget {
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

  const _SongContextMenuSheet({
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
  });

  String? _formatStat() {
    if (playCount != null && playCount!.isNotEmpty) {
      return stripYtLabel(playCount);
    }
    if (viewCount != null) return viewCount!.toCompact();
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

    // Lazy enrichment: if artistId/albumId weren't saved (e.g. old liked songs),
    // fetch the full song data to recover them and persist back to DB.
    // TODO: remove once enrichment backfill is complete — resolvedArtistId
    //       will always equal artistId (the constructor field).
    final songAsync = ref.watch(_songFullProvider(videoId));
    final resolvedArtistId =
        artistId ?? songAsync.asData?.value.artist.artistId;
    final resolvedAlbumId = albumId ?? songAsync.asData?.value.album?.albumId;
    // TODO: remove ref.listen block once enrichment backfill is complete.
    ref.listen(_songFullProvider(videoId), (_, next) {
      if (next is AsyncData && (artistId == null || albumId == null)) {
        final data = next.value;
        if (data == null) return;
        final fullId = data.artist.artistId;
        final fullAlbumId = data.album?.albumId;
        if (fullId != null || fullAlbumId != null) {
          ref
              .read(libraryNotifierProvider.notifier)
              .updateLikedSongMetadata(
                videoId,
                artistId: artistId ?? fullId,
                albumId: albumId ?? fullAlbumId,
              );
        }
      }
    });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_formatStat() != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatStat()!,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionTile(
                    icon: LucideIcons.play,
                    label: AppLocalizations.of(context)!.playNow,
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(actionFeedbackProvider.notifier)
                          .report(AppLocalizations.of(context)!.playNow);
                      player.playVideoId(videoId, isVideo: isVideo);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listVideo,
                    label: AppLocalizations.of(context)!.playNext,
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(actionFeedbackProvider.notifier)
                          .report(AppLocalizations.of(context)!.playNext);
                      player.playNextVideoId(
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        durationSec: duration,
                        isVideo: isVideo,
                        albumName: albumName,
                        artistId: resolvedArtistId,
                        albumId: resolvedAlbumId,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listMusic,
                    label: AppLocalizations.of(context)!.addToQueue,
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(actionFeedbackProvider.notifier)
                          .report(AppLocalizations.of(context)!.addToQueue);
                      player.addToQueueVideoId(
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        durationSec: duration,
                        isVideo: isVideo,
                        albumName: albumName,
                        artistId: resolvedArtistId,
                        albumId: resolvedAlbumId,
                      );
                    },
                  ),
                  if (resolvedArtistId != null)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$resolvedArtistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (resolvedAlbumId != null)
                    _ActionTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                      onTap: () {
                        context.push('/album/$resolvedAlbumId');
                        Navigator.pop(context);
                      },
                    ),
                  _ActionTile(
                    icon: LucideIcons.radio,
                    label: AppLocalizations.of(context)!.startRadio,
                    onTap: () {
                      final useCase = ref.read(startRadioUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      final currentPlayer = player;
                      Navigator.pop(context);
                      _startSongRadio(useCase, currentPlayer, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.plus,
                    label: AppLocalizations.of(context)!.addToPlaylist,
                    onTap: () {
                      Navigator.pop(context);
                      _showPlaylistPicker(
                        context,
                        ref,
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                      );
                    },
                  ),
                  _LikeActionTile(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    artistId: resolvedArtistId,
                    albumId: albumId,
                    isVideo: isVideo,
                  ),
                  _ActionTile(
                    icon:
                        isDownloaded
                            ? LucideIcons.checkCircle
                            : LucideIcons.download,
                    label:
                        isDownloaded
                            ? AppLocalizations.of(context)!.downloaded
                            : AppLocalizations.of(context)!.download,
                    onTap: () {
                      Navigator.pop(context);
                      if (isDownloaded) {
                        showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.alreadyDownloaded,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.alreadyDownloadedConfirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      AppLocalizations.of(context)!.cancel,
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.continueAction,
                                    ),
                                  ),
                                ],
                              ),
                        ).then((proceed) {
                          if (proceed == true) {
                            ref
                                .read(activeDownloadsProvider.notifier)
                                .startDownload(
                                  videoId: videoId,
                                  title: title,
                                  artist: artist,
                                  thumbnailUrl: thumbnailUrl,
                                );
                          }
                        });
                      } else {
                        ref
                            .read(activeDownloadsProvider.notifier)
                            .startDownload(
                              videoId: videoId,
                              title: title,
                              artist: artist,
                              thumbnailUrl: thumbnailUrl,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.downloadStarted,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'https://music.youtube.com/watch?v=$videoId',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSongRadio(
    StartRadioUseCase useCase,
    PlayerNotifier currentPlayer,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final result = await useCase.execute(videoId);
      await currentPlayer.playNow([result.firstItem]);
      if (result.remaining.isNotEmpty) {
        final pendingItems = useCase.toPendingItems(result.remaining);
        currentPlayer.addAllToQueue(pendingItems);
      }
    } catch (e) {
      feedback.report('Failed to start radio: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artist context menu
// ─────────────────────────────────────────────────────────────────────────────

class _ArtistContextMenuSheet extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? monthlyListeners;

  const _ArtistContextMenuSheet({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.circle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (monthlyListeners != null &&
                          monthlyListeners!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          stripYtLabel(monthlyListeners) ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionTile(
                    icon: LucideIcons.play,
                    label: AppLocalizations.of(context)!.playTopSongs,
                    onTap: () {
                      final artistFuture = ref.read(
                        artistProvider(artistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playAlbumUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _playTopSongs(artistFuture, useCase, player, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.shuffle,
                    label: AppLocalizations.of(context)!.shuffle,
                    onTap: () {
                      final artistFuture = ref.read(
                        artistProvider(artistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playAlbumUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _shufflePlay(artistFuture, useCase, player, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.user,
                    label: AppLocalizations.of(context)!.goToArtist,
                    onTap: () {
                      context.push('/artist/$artistId');
                      Navigator.pop(context);
                    },
                  ),
                  _FollowArtistActionTile(
                    artistId: artistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                  ),
                  _ActionTile(
                    icon: LucideIcons.radio,
                    label: AppLocalizations.of(context)!.artistRadio,
                    onTap: () {
                      final artistFuture = ref.read(
                        artistProvider(artistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(startRadioUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _startRadio(artistFuture, useCase, player, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'https://music.youtube.com/channel/$artistId',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<SongDetailed>> _fetchSongs(
    Future<ArtistFull> artistFuture,
  ) async {
    final artist = await artistFuture;
    return artist.topSongs;
  }

  Future<void> _playTopSongs(
    Future<ArtistFull> artistFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchSongs(artistFuture);
      if (songs.isEmpty) return;
      feedback.report('Playing $name…');
      final items = await useCase.execute(songs);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _shufflePlay(
    Future<ArtistFull> artistFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchSongs(artistFuture);
      if (songs.isEmpty) return;
      feedback.report('Shuffling $name…');
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _startRadio(
    Future<ArtistFull> artistFuture,
    StartRadioUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchSongs(artistFuture);
      if (songs.isEmpty) return;
      final result = await useCase.execute(songs.first.videoId);
      await player.playNow([result.firstItem]);
      if (result.remaining.isNotEmpty) {
        final pendingItems = useCase.toPendingItems(result.remaining);
        player.addAllToQueue(pendingItems);
      }
    } catch (e) {
      feedback.report('Failed to start radio: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Album context menu
// ─────────────────────────────────────────────────────────────────────────────

class _AlbumContextMenuSheet extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? artistId;
  final String? thumbnailUrl;
  final int? year;

  const _AlbumContextMenuSheet({
    required this.albumId,
    required this.name,
    required this.artist,
    this.artistId,
    this.thumbnailUrl,
    this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [artist, if (year != null) '$year'].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionTile(
                    icon: LucideIcons.play,
                    label: AppLocalizations.of(context)!.playAll,
                    onTap: () {
                      final albumFuture = ref.read(
                        albumProvider(albumId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playAlbumUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _playAlbumSequential(
                        albumFuture,
                        useCase,
                        player,
                        feedback,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.shuffle,
                    label: AppLocalizations.of(context)!.shufflePlay,
                    onTap: () {
                      final albumFuture = ref.read(
                        albumProvider(albumId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playAlbumUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _shuffleAlbumPlay(albumFuture, useCase, player, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listMusic,
                    label: AppLocalizations.of(context)!.addToQueue,
                    onTap: () {
                      final albumFuture = ref.read(
                        albumProvider(albumId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playAlbumUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _addAlbumToQueue(albumFuture, useCase, player, feedback);
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.disc,
                    label: AppLocalizations.of(context)!.goToAlbum,
                    onTap: () {
                      context.push('/album/$albumId');
                      Navigator.pop(context);
                    },
                  ),
                  if (artistId != null)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$artistId');
                        Navigator.pop(context);
                      },
                    ),
                  _LikeAlbumActionTile(
                    albumId: albumId,
                    name: name,
                    artistName: artist,
                    thumbnailUrl: thumbnailUrl,
                    year: year,
                  ),
                  _ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'https://music.youtube.com/playlist?list=$albumId',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<SongDetailed>> _fetchAlbumSongs(
    Future<AlbumFull> albumFuture,
  ) async {
    final album = await albumFuture;
    return album.songs;
  }

  Future<void> _playAlbumSequential(
    Future<AlbumFull> albumFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      feedback.report('Playing $name…');
      final items = await useCase.execute(songs);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _shuffleAlbumPlay(
    Future<AlbumFull> albumFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      feedback.report('Shuffling $name…');
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _addAlbumToQueue(
    Future<AlbumFull> albumFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      final items = await useCase.execute(songs, playIndex: -1);
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report('Added ${items.length} songs to queue');
      }
    } catch (e) {
      feedback.report('Failed to add to queue: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlist context menu
// ─────────────────────────────────────────────────────────────────────────────

class _PlaylistContextMenuSheet extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;

  const _PlaylistContextMenuSheet({
    required this.playlistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$artist · Playlist',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionTile(
                    icon: LucideIcons.play,
                    label: AppLocalizations.of(context)!.playAll,
                    onTap: () {
                      final videosFuture = ref.read(
                        playlistVideosProvider(playlistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playPlaylistUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _playPlaylistSequential(
                        videosFuture,
                        useCase,
                        player,
                        feedback,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.shuffle,
                    label: AppLocalizations.of(context)!.shufflePlay,
                    onTap: () {
                      final videosFuture = ref.read(
                        playlistVideosProvider(playlistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playPlaylistUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _shufflePlaylistPlay(
                        videosFuture,
                        useCase,
                        player,
                        feedback,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listMusic,
                    label: AppLocalizations.of(context)!.addToQueue,
                    onTap: () {
                      final videosFuture = ref.read(
                        playlistVideosProvider(playlistId).future,
                      );
                      final player = ref.read(playerStateProvider.notifier);
                      final useCase = ref.read(playPlaylistUseCaseProvider);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _addPlaylistToQueue(
                        videosFuture,
                        useCase,
                        player,
                        feedback,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listVideo,
                    label: AppLocalizations.of(context)!.goToPlaylist,
                    onTap: () {
                      context.push('/playlist/$playlistId');
                      Navigator.pop(context);
                    },
                  ),
                  _LikePlaylistActionTile(
                    playlistId: playlistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                  ),
                  _ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'https://music.youtube.com/playlist?list=$playlistId',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playPlaylistSequential(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      feedback.report('Playing $name…');
      final items = await useCase.execute(videos);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _shufflePlaylistPlay(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      feedback.report('Shuffling $name…');
      final shuffled = List<VideoDetailed>.from(videos)..shuffle();
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _addPlaylistToQueue(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      final items = await useCase.execute(videos, playIndex: -1);
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report('Added ${items.length} songs to queue');
      }
    } catch (e) {
      feedback.report('Failed to add to queue: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom playlist (local) context menu
// ─────────────────────────────────────────────────────────────────────────────

class _CustomPlaylistContextMenuSheet extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const _CustomPlaylistContextMenuSheet({
    required this.playlist,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: null,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Playlist',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionTile(
                    icon: LucideIcons.play,
                    label: l10n.playAll,
                    onTap: () {
                      final player = ref.read(playerStateProvider.notifier);
                      final notifier = ref.read(
                        libraryNotifierProvider.notifier,
                      );
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _playAll(
                        ref,
                        playlist.id,
                        player,
                        notifier,
                        feedback,
                        l10n,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.shuffle,
                    label: l10n.shufflePlay,
                    onTap: () {
                      final player = ref.read(playerStateProvider.notifier);
                      final notifier = ref.read(
                        libraryNotifierProvider.notifier,
                      );
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _shufflePlay(
                        ref,
                        playlist.id,
                        player,
                        notifier,
                        feedback,
                        l10n,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listMusic,
                    label: l10n.addToQueue,
                    onTap: () {
                      final player = ref.read(playerStateProvider.notifier);
                      final notifier = ref.read(
                        libraryNotifierProvider.notifier,
                      );
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _addToQueue(
                        ref,
                        playlist.id,
                        player,
                        notifier,
                        feedback,
                        l10n,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.pencil,
                    label: l10n.renamePlaylist,
                    onTap: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder:
                            (_) => CreatePlaylistDialog(
                              initialName: playlist.name,
                              title: l10n.renamePlaylist,
                            ),
                      );
                      if (result != null &&
                          result.isNotEmpty &&
                          result != playlist.name) {
                        if (!context.mounted) return;
                        final notifier = ref.read(
                          libraryNotifierProvider.notifier,
                        );
                        Navigator.pop(context);
                        await notifier.updatePlaylist(
                          playlist.id,
                          name: result,
                        );
                        ref.invalidate(playlistsProvider);
                        onUpdated();
                      }
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.trash2,
                    label: l10n.deletePlaylist,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: Text(l10n.deletePlaylist),
                              content: Text(
                                l10n.deletePlaylistConfirm(playlist.name),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        if (!context.mounted) return;
                        final notifier = ref.read(
                          libraryNotifierProvider.notifier,
                        );
                        Navigator.pop(context);
                        await notifier.deletePlaylist(playlist.id);
                        ref.invalidate(playlistsProvider);
                        onUpdated();
                      }
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.listVideo,
                    label: l10n.goToPlaylist,
                    onTap: () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      Navigator.pop(context);
                      nav.push(
                        MaterialPageRoute(
                          builder:
                              (_) => PlaylistDetailView(
                                playlist: playlist,
                                onUpdated: onUpdated,
                              ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playAll(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    LibraryNotifier notifier,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    feedback.report(l10n.playingPlaylist(playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      final items = await notifier.buildLocalPlaylistItems(entries);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (_) {}
  }

  Future<void> _shufflePlay(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    LibraryNotifier notifier,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    feedback.report(l10n.shufflingPlaylist(playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      final shuffled = List<PlaylistEntryModel>.from(entries)..shuffle();
      final items = await notifier.buildLocalPlaylistItems(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (_) {}
  }

  Future<void> _addToQueue(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    LibraryNotifier notifier,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      final items = await notifier.buildLocalPlaylistItems(entries);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      feedback.report(l10n.addedToQueue(items.length));
    } catch (e) {
      feedback.report(l10n.failedToAddToQueue(e.toString()));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared action tiles
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      dense: true,
    );
  }
}

class _LoadingTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LoadingTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: ColoredBox(color: cs.onSurface.withAlpha(40)),
        ),
        title: SizedBox(
          height: 14,
          child: ColoredBox(color: cs.onSurface.withAlpha(30)),
        ),
        enabled: false,
        dense: true,
      ),
    );
  }
}

class _LikeActionTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? artistId;
  final String? albumId;
  final bool isVideo;

  const _LikeActionTile({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.artistId,
    this.albumId,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading:
          () => ListTile(
            leading: Icon(LucideIcons.heart),
            title: Text(AppLocalizations.of(context)!.like),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked ? LucideIcons.heart : LucideIcons.heart,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedSong(
                  LikedSongModel(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    artistId: artistId,
                    albumId: albumId,
                    addedAt: DateTime.now(),
                    isVideo: isVideo,
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class _FollowArtistActionTile extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;

  const _FollowArtistActionTile({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedAsync = ref.watch(followedArtistProvider(artistId));
    return followedAsync.when(
      loading:
          () => ListTile(
            leading: Icon(LucideIcons.userPlus),
            title: Text(AppLocalizations.of(context)!.follow),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
        return ListTile(
          leading: Icon(
            isFollowing ? LucideIcons.userMinus : LucideIcons.userPlus,
            color: isFollowing ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(
            isFollowing
                ? AppLocalizations.of(context)!.following
                : AppLocalizations.of(context)!.follow,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleFollowedArtist(
                  FollowedArtistModel(
                    artistId: artistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class _LikeAlbumActionTile extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artistName;
  final String? thumbnailUrl;
  final int? year;

  const _LikeAlbumActionTile({
    required this.albumId,
    required this.name,
    required this.artistName,
    this.thumbnailUrl,
    this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedAlbumProvider(albumId));
    return likedAsync.when(
      loading:
          () => ListTile(
            leading: Icon(LucideIcons.heart),
            title: Text(AppLocalizations.of(context)!.like),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked ? LucideIcons.heart : LucideIcons.heart,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedAlbum(
                  LikedAlbumModel(
                    albumId: albumId,
                    name: name,
                    artistName: artistName,
                    thumbnailUrl: thumbnailUrl,
                    year: year,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class _LikePlaylistActionTile extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? thumbnailUrl;

  const _LikePlaylistActionTile({
    required this.playlistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaylistProvider(playlistId));
    return likedAsync.when(
      loading:
          () => ListTile(
            leading: Icon(LucideIcons.heart),
            title: Text(AppLocalizations.of(context)!.like),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked ? LucideIcons.heart : LucideIcons.heart,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedPlaylist(
                  LikedPlaylistModel(
                    playlistId: playlistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlist picker (shared by song context menu)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  String videoId, {
  String? title,
  String? artist,
  String? thumbnailUrl,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder:
        (_) => _PlaylistPickerSheet(
          videoId: videoId,
          title: title,
          artist: artist,
          thumbnailUrl: thumbnailUrl,
        ),
  );
}

class _PlaylistPickerSheet extends ConsumerStatefulWidget {
  final String videoId;
  final String? title;
  final String? artist;
  final String? thumbnailUrl;

  const _PlaylistPickerSheet({
    required this.videoId,
    this.title,
    this.artist,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<_PlaylistPickerSheet> createState() =>
      _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends ConsumerState<_PlaylistPickerSheet> {
  late Future<List<LocalPlaylistModel>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture =
        ref.read(libraryNotifierProvider.notifier).getAllPlaylists();
  }

  Future<void> _createAndAdd(String name) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);
    await notifier.createPlaylist(name);
    final playlists = await notifier.getAllPlaylists();
    final created = playlists.firstWhere((p) => p.name == name);
    await notifier.addEntryToPlaylist(
      created.id,
      widget.videoId,
      title: widget.title,
      artist: widget.artist,
      thumbnailUrl: widget.thumbnailUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FutureBuilder<List<LocalPlaylistModel>>(
          future: _playlistsFuture,
          builder: (context, AsyncSnapshot<List<LocalPlaylistModel>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final playlists = snapshot.data ?? [];
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.addToPlaylist,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.plus),
                      label: Text(
                        AppLocalizations.of(context)!.createNewPlaylist,
                      ),
                      onPressed: () async {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (_) => const CreatePlaylistDialog(),
                        );
                        if (name != null && name.isNotEmpty) {
                          await _createAndAdd(name);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)!.addedTo(name),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    AppLocalizations.of(context)!.addToPlaylist,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: const Icon(LucideIcons.listVideo),
                        title: Text(playlist.name),
                        onTap: () async {
                          await ref
                              .read(libraryNotifierProvider.notifier)
                              .addEntryToPlaylist(
                                playlist.id,
                                widget.videoId,
                                title: widget.title,
                                artist: widget.artist,
                                thumbnailUrl: widget.thumbnailUrl,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.addedToPlaylist(playlist.name),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
