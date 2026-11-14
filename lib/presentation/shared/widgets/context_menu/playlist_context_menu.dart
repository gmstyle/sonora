import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/link/sonora_link.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../core/utils/playable_tracks.dart';
import '../../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/playlist/providers/playlist_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/play_playlist_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../detail_actions_bar.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class PlaylistContextMenuSheet extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;
  final bool hideGoToPlaylist;
  final Set<String> omitActionIds;

  const PlaylistContextMenuSheet({
    super.key,
    required this.playlistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
    this.hideGoToPlaylist = false,
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
                      if (artist != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$artist · Playlist',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                  if (showAction(omitActionIds, DetailActionId.play))
                    ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playAll,
                      enabled: !isOffline,
                      onTap: () {
                        final videosFuture = ref.read(
                          playlistVideosProvider(playlistId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playPlaylistUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _playPlaylistSequential(
                          videosFuture,
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
                        final videosFuture = ref.read(
                          playlistVideosProvider(playlistId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playPlaylistUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _shufflePlaylistPlay(
                          videosFuture,
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
                        final videosFuture = ref.read(
                          playlistVideosProvider(playlistId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playPlaylistUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _addPlaylistToQueue(
                          videosFuture,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (!hideGoToPlaylist)
                    ActionTile(
                      icon: LucideIcons.listVideo,
                      label: AppLocalizations.of(context)!.goToPlaylist,
                      onTap: () {
                        context.push('/playlist/$playlistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.save))
                    LikePlaylistActionTile(
                      playlistId: playlistId,
                      name: name,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (showAction(omitActionIds, DetailActionId.download))
                    ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      enabled: !isOffline,
                      onTap: () {
                        final videosFuture = ref.read(
                          playlistVideosProvider(playlistId).future,
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
                        _downloadPlaylist(
                          rootContext,
                          container,
                          videosFuture,
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
                            kind: SonoraLinkKind.playlist,
                            id: playlistId,
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

  Future<void> _playPlaylistSequential(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      feedback.report(l10n.playingPlaylist(name));
      await player.playPlaylist(videos, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _shufflePlaylistPlay(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      feedback.report(l10n.shufflingPlaylist(name));
      final shuffled = List<VideoDetailed>.from(videos)..shuffle();
      await player.playPlaylist(shuffled, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _addPlaylistToQueue(
    Future<List<VideoDetailed>> videosFuture,
    PlayPlaylistUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      final items = await useCase.execute(videos, playIndex: -1);
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      feedback.report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  Future<void> _downloadPlaylist(
    BuildContext context,
    ProviderContainer container,
    Future<List<VideoDetailed>> videosFuture,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      final notifier = container.read(activeDownloadsProvider.notifier);
      final toDownload = playableVideos(videos)
          .where((v) => !notifier.isDownloading(v.videoId))
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
              .where((d) => toDownload.any((v) => v.videoId == d.videoId))
              .toList() ??
          [];
      if (alreadyDownloaded.isNotEmpty && context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.alreadyDownloaded),
            content: Text(
              l10n.alreadyDownloadedSongs(alreadyDownloaded.length, name),
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
      final batchId = 'playlist:$playlistId';
      final batchTotal = toDownload.length;
      final sourceIndex = {
        for (var i = 0; i < videos.length; i++) videos[i].videoId: i,
      };

      for (final video in toDownload) {
        if (alreadyDownloadedIds.contains(video.videoId)) {
          await notifier.deleteDownload(video.videoId);
        }
        unawaited(
          notifier.startDownload(
            videoId: video.videoId,
            title: video.name,
            artist: displayArtists(video.artists),
            artistsJson: encodeArtistsJson(video.artists),
            thumbnailUrl: video.thumbnails.isNotEmpty
                ? video.thumbnails.last.url
                : null,
            subdirectory: name,
            isExplicit: video.isExplicit,
            isVideo: true,
            batchId: batchId,
            batchName: name,
            batchTotal: batchTotal,
            collectionIndex: sourceIndex[video.videoId],
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
