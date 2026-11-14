import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/link/sonora_link.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../core/utils/playable_tracks.dart';
import '../../../../domain/usecases/player/play_album_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/album/providers/album_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/play_album_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../detail_actions_bar.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class AlbumContextMenuSheet extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? artistId;
  final String? thumbnailUrl;
  final int? year;
  final bool hideGoToAlbum;
  final Set<String> omitActionIds;

  const AlbumContextMenuSheet({
    super.key,
    required this.albumId,
    required this.name,
    required this.artist,
    this.artistId,
    this.thumbnailUrl,
    this.year,
    this.hideGoToAlbum = false,
    this.omitActionIds = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
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
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                  if (showAction(omitActionIds, DetailActionId.play))
                    ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playAll,
                      enabled: !isOffline,
                      onTap: () {
                        final albumFuture = ref.read(
                          albumProvider(albumId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _playAlbumSequential(
                          albumFuture,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.shuffle))
                    ActionTile(
                      icon: LucideIcons.shuffle,
                      label: AppLocalizations.of(context)!.shufflePlay,
                      enabled: !isOffline,
                      onTap: () {
                        final albumFuture = ref.read(
                          albumProvider(albumId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _shuffleAlbumPlay(
                          albumFuture,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.queue))
                    ActionTile(
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
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _addAlbumToQueue(
                          albumFuture,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (!hideGoToAlbum)
                    ActionTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                      onTap: () {
                        context.push('/album/$albumId');
                        Navigator.pop(context);
                      },
                    ),
                  if (artistId != null)
                    ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$artistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.save))
                    LikeAlbumActionTile(
                      albumId: albumId,
                      name: name,
                      artistName: artist,
                      artistId: artistId,
                      thumbnailUrl: thumbnailUrl,
                      year: year,
                    ),
                  if (showAction(omitActionIds, DetailActionId.download))
                    ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      enabled: !isOffline,
                      onTap: () {
                        final albumFuture = ref.read(
                          albumProvider(albumId).future,
                        );
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final container = ProviderScope.containerOf(context);
                        final rootContext = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        Navigator.pop(context);
                        _downloadAlbum(
                          rootContext,
                          container,
                          albumFuture,
                          feedback,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.share))
                    ActionTile(
                      icon: LucideIcons.share2,
                      label: AppLocalizations.of(context)!.share,
                      onTap: () {
                        final share = shareSonoraLinkFromMenu(
                          ref,
                          context,
                          link: SonoraLink(
                            kind: SonoraLinkKind.album,
                            id: albumId,
                          ),
                          title: name,
                          subtitle: artist,
                        );
                        Navigator.pop(context);
                        unawaited(share);
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
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      feedback.report(l10n.playingPlaylist(name));
      final items = await useCase.execute(songs);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _shuffleAlbumPlay(
    Future<AlbumFull> albumFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      feedback.report(l10n.shufflingPlaylist(name));
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _addAlbumToQueue(
    Future<AlbumFull> albumFuture,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAlbumSongs(albumFuture);
      if (songs.isEmpty) return;
      final items = await useCase.execute(songs, playIndex: -1);
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      feedback.report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  Future<void> _downloadAlbum(
    BuildContext context,
    ProviderContainer container,
    Future<AlbumFull> albumFuture,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final album = await albumFuture;
      if (album.songs.isEmpty) return;
      final notifier = container.read(activeDownloadsProvider.notifier);
      final toDownload = playableSongs(album.songs)
          .where((s) => !notifier.isDownloading(s.videoId))
          .toList();
      if (toDownload.isEmpty) {
        if (context.mounted) {
          feedback.report(
            AppLocalizations.of(context)!.allSongsAlreadyDownloading,
          );
        }
        return;
      }

      final alreadyDownloaded =
          container
              .read(allDownloadsProvider)
              .asData
              ?.value
              .where((d) => toDownload.any((s) => s.videoId == d.videoId))
              .toList() ??
          [];
      if (alreadyDownloaded.isNotEmpty && context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.alreadyDownloaded),
            content: Text(
              l10n.alreadyDownloadedSongs(alreadyDownloaded.length, album.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.continueAction),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      final alreadyDownloadedIds = alreadyDownloaded
          .map((d) => d.videoId)
          .toSet();
      final batchId = 'album:${album.albumId}';
      final batchTotal = toDownload.length;
      final sourceIndex = {
        for (var i = 0; i < album.songs.length; i++) album.songs[i].videoId: i,
      };

      for (final song in toDownload) {
        if (alreadyDownloadedIds.contains(song.videoId)) {
          await notifier.deleteDownload(song.videoId);
        }
        unawaited(
          notifier.startDownload(
            videoId: song.videoId,
            title: song.name,
            artist: displayArtists(song.artists),
            artistsJson: encodeArtistsJson(song.artists),
            thumbnailUrl: song.thumbnails.isNotEmpty
                ? song.thumbnails.last.url
                : null,
            subdirectory: album.name,
            isExplicit: song.isExplicit,
            batchId: batchId,
            batchName: album.name,
            batchTotal: batchTotal,
            collectionIndex: sourceIndex[song.videoId],
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to download: $e');
      if (context.mounted) {
        feedback.report(
          AppLocalizations.of(context)!.downloadFailed,
          kind: FeedbackKind.error,
        );
      }
    }
  }
}
