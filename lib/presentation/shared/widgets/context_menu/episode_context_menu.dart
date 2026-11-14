import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/link/sonora_link.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/play_video_id_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../detail_affinity_button.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class EpisodeContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String name;
  final String? podcastName;
  final String? podcastBrowseId;
  final String? thumbnailUrl;
  final String? date;
  final void Function(String podcastBrowseId)? onGoToPodcast;
  final bool hideGoToPodcast;

  const EpisodeContextMenuSheet({
    super.key,
    required this.videoId,
    required this.name,
    this.podcastName,
    this.podcastBrowseId,
    this.thumbnailUrl,
    this.date,
    this.onGoToPodcast,
    this.hideGoToPodcast = false,
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
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (podcastName != null && podcastName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          podcastName!,
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
                  ActionTile(
                    icon: LucideIcons.play,
                    label: AppLocalizations.of(context)!.playNow,
                    onTap: () {
                      final useCase = ref.read(playVideoIdUseCaseProvider);
                      final player = ref.read(playerStateProvider.notifier);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      final l10n = AppLocalizations.of(context)!;
                      Navigator.pop(context);
                      _playEpisode(useCase, player, feedback, l10n);
                    },
                  ),
                  if (podcastBrowseId != null && !hideGoToPodcast)
                    ActionTile(
                      icon: LucideIcons.micVocal,
                      label: AppLocalizations.of(context)!.goToPodcast,
                      onTap: () {
                        final browseId = podcastBrowseId!;
                        final goToPodcast = onGoToPodcast;
                        if (goToPodcast != null) {
                          Navigator.pop(context);
                          goToPodcast(browseId);
                        } else {
                          context.push('/podcast/$browseId');
                          Navigator.pop(context);
                        }
                      },
                    ),
                  LikeEpisodeActionTile(
                    videoId: videoId,
                    name: name,
                    podcastName: podcastName,
                    podcastBrowseId: podcastBrowseId,
                    thumbnailUrl: thumbnailUrl,
                    date: date,
                  ),
                  ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      final share = shareSonoraLinkFromMenu(
                        ref,
                        context,
                        link: SonoraLink(
                          kind: SonoraLinkKind.episode,
                          id: videoId,
                        ),
                        title: name,
                        subtitle: podcastName,
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

  Future<void> _playEpisode(
    PlayVideoIdUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final url = await useCase.resolveUrl(videoId);
      final track = QueueTrack(
        videoId: videoId,
        url: url,
        isVideo: false,
        contentType: 'episode',
        podcastBrowseId: podcastBrowseId,
        title: name,
        artist: podcastName,
        artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl!) : null,
      );
      await player.playNow([track.toFreshMediaItem()]);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }
}

class LikeEpisodeActionTile extends ConsumerWidget {
  final String videoId;
  final String name;
  final String? podcastName;
  final String? podcastBrowseId;
  final String? thumbnailUrl;
  final String? date;

  const LikeEpisodeActionTile({
    super.key,
    required this.videoId,
    required this.name,
    this.podcastName,
    this.podcastBrowseId,
    this.thumbnailUrl,
    this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedEpisodeProvider(videoId));
    return likedAsync.when(
      loading: () => ListTile(
        leading: const Icon(LucideIcons.bookmark),
        title: Text(AppLocalizations.of(context)!.like),
        enabled: false,
        dense: true,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSaved = liked != null;
        return ListTile(
          leading: Icon(
            isSaved
                ? DetailAffinityButton.bookmarkActive
                : DetailAffinityButton.bookmarkIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isSaved,
              activeColor: DetailAffinityButton.brandColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isSaved
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            if (isSaved) {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .deleteLikedEpisode(videoId);
            } else {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .toggleLikedEpisode(
                    LikedEpisodeModel(
                      videoId: videoId,
                      name: name,
                      podcastName: podcastName,
                      podcastBrowseId: podcastBrowseId,
                      thumbnailUrl: thumbnailUrl,
                      date: date,
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
