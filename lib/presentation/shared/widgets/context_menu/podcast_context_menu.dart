import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/link/sonora_link.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../domain/usecases/player/play_podcast_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/podcast/providers/podcast_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/play_podcast_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../detail_actions_bar.dart';
import '../detail_affinity_button.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class PodcastContextMenuSheet extends ConsumerWidget {
  final String browseId;
  final String name;
  final String? author;
  final String? thumbnailUrl;
  final bool hideGoToPodcast;
  final Set<String> omitActionIds;

  const PodcastContextMenuSheet({
    super.key,
    required this.browseId,
    required this.name,
    this.author,
    this.thumbnailUrl,
    this.hideGoToPodcast = false,
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
                      if (author != null && author!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          author!,
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
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _playPodcast(repo, player, feedback, l10n);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.shuffle))
                    ActionTile(
                      icon: LucideIcons.shuffle,
                      label: AppLocalizations.of(context)!.shufflePlay,
                      enabled: !isOffline,
                      onTap: () {
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _shufflePodcast(repo, player, feedback, l10n);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.queue))
                    ActionTile(
                      icon: LucideIcons.listMusic,
                      label: AppLocalizations.of(context)!.addToQueue,
                      onTap: () {
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playPodcastUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _addPodcastToQueue(
                          repo,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (!hideGoToPodcast)
                    ActionTile(
                      icon: LucideIcons.micVocal,
                      label: AppLocalizations.of(context)!.goToPodcast,
                      onTap: () {
                        context.push('/podcast/$browseId');
                        Navigator.pop(context);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.save))
                    LikePodcastActionTile(
                      browseId: browseId,
                      name: name,
                      authorName: author,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (showAction(omitActionIds, DetailActionId.download))
                    ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      enabled: !isOffline,
                      onTap: () {
                        final podcastFuture = ref.read(
                          podcastProvider(browseId).future,
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
                        _downloadPodcast(
                          rootContext,
                          container,
                          podcastFuture,
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
                            kind: SonoraLinkKind.podcast,
                            id: browseId,
                          ),
                          title: name,
                          subtitle: author,
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

  Future<void> _playPodcast(
    MusicRepository repo,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      feedback.report(l10n.playingPlaylist(name));
      final podcast = await repo.getPodcast(browseId);
      if (podcast.episodes.isEmpty) return;
      await player.playPodcast(
        podcast.episodes,
        podcastBrowseId: browseId,
        podcastName: name,
        authorName: author ?? podcast.author?.name,
        authorId: podcast.author?.artistId,
      );
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _shufflePodcast(
    MusicRepository repo,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      feedback.report(l10n.shufflingPlaylist(name));
      final podcast = await repo.getPodcast(browseId);
      if (podcast.episodes.isEmpty) return;
      final shuffled = List.of(podcast.episodes)..shuffle();
      await player.playPodcast(
        shuffled,
        podcastBrowseId: browseId,
        podcastName: name,
        authorName: author ?? podcast.author?.name,
        authorId: podcast.author?.artistId,
      );
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _addPodcastToQueue(
    MusicRepository repo,
    PlayPodcastUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final podcast = await repo.getPodcast(browseId);
      final episodes = podcast.episodes
          .where((e) => e.videoId.isNotEmpty)
          .toList();
      if (episodes.isEmpty) return;
      final items = await useCase.execute(
        episodes,
        podcastBrowseId: browseId,
        podcastName: name,
        authorName: author ?? podcast.author?.name,
        authorId: podcast.author?.artistId,
        playIndex: -1,
      );
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report(l10n.addedEpisodesToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      feedback.report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  Future<void> _downloadPodcast(
    BuildContext context,
    ProviderContainer container,
    Future<PodcastFull> podcastFuture,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final podcast = await podcastFuture;
      final notifier = container.read(activeDownloadsProvider.notifier);
      final episodes = podcast.episodes.where((e) => e.videoId.isNotEmpty);
      final toDownload = episodes
          .where((e) => !notifier.isDownloading(e.videoId))
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
              .where((d) => toDownload.any((e) => e.videoId == d.videoId))
              .toList() ??
          [];
      if (alreadyDownloaded.isNotEmpty && context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.alreadyDownloaded),
            content: Text(
              l10n.alreadyDownloadedSongs(
                alreadyDownloaded.length,
                podcast.name,
              ),
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
      final batchId = 'podcast:${podcast.browseId}';
      final batchTotal = toDownload.length;
      final allEpisodes = podcast.episodes.toList();
      final sourceIndex = {
        for (var i = 0; i < allEpisodes.length; i++)
          if (allEpisodes[i].videoId.isNotEmpty) allEpisodes[i].videoId: i,
      };

      for (final episode in toDownload) {
        if (alreadyDownloadedIds.contains(episode.videoId)) {
          await notifier.deleteDownload(episode.videoId);
        }
        unawaited(
          notifier.startDownload(
            videoId: episode.videoId,
            title: episode.name,
            artist: podcast.author?.name ?? podcast.name,
            thumbnailUrl: episode.thumbnails.isNotEmpty
                ? episode.thumbnails.last.url
                : null,
            subdirectory: podcast.name,
            isVideo: false,
            batchId: batchId,
            batchName: podcast.name,
            batchTotal: batchTotal,
            collectionIndex: sourceIndex[episode.videoId],
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

class LikePodcastActionTile extends ConsumerWidget {
  final String browseId;
  final String name;
  final String? authorName;
  final String? thumbnailUrl;

  const LikePodcastActionTile({
    super.key,
    required this.browseId,
    required this.name,
    this.authorName,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPodcastProvider(browseId));
    return likedAsync.when(
      loading: () => ListTile(
        leading: const Icon(LucideIcons.bookmark),
        title: Text(AppLocalizations.of(context)!.subscribe),
        enabled: false,
        dense: true,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSubscribed = liked != null;
        return ListTile(
          leading: Icon(
            isSubscribed
                ? DetailAffinityButton.bookmarkActive
                : DetailAffinityButton.bookmarkIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isSubscribed,
              activeColor: DetailAffinityButton.brandColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isSubscribed
                ? AppLocalizations.of(context)!.subscribed
                : AppLocalizations.of(context)!.subscribe,
          ),
          onTap: () async {
            if (isSubscribed) {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .deleteLikedPodcast(browseId);
            } else {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .toggleLikedPodcast(
                    LikedPodcastModel(
                      browseId: browseId,
                      name: name,
                      authorName: authorName,
                      thumbnailUrl: thumbnailUrl,
                      addedAt: DateTime.now(),
                    ),
                  );
            }
          },
          dense: true,
        );
      },
    );
  }
}
