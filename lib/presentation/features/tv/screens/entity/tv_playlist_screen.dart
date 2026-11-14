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
import '../../../../providers/play_playlist_use_case_provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/detail_actions_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../playlist/providers/playlist_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_actions_bar.dart';
import '../../widgets/tv_track_row.dart';

class TvPlaylistScreen extends ConsumerWidget {
  final String playlistId;

  const TvPlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadPlaylist,
          onRetry: () {
            ref.invalidate(playlistProvider(playlistId));
            ref.invalidate(playlistVideosProvider(playlistId));
          },
        ),
      ),
      data: (playlist) => videosAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          body: ErrorRetryWidget(
            message: l10n.failedToLoadPlaylist,
            onRetry: () => ref.invalidate(playlistVideosProvider(playlistId)),
          ),
        ),
        data: (videos) => _TvPlaylistBody(playlist: playlist, videos: videos),
      ),
    );
  }
}

class _TvPlaylistBody extends ConsumerWidget {
  final PlaylistFull playlist;
  final List<VideoDetailed> videos;

  const _TvPlaylistBody({required this.playlist, required this.videos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(isOfflineProvider);
    final liked = ref
        .watch(likedPlaylistProvider(playlist.playlistId))
        .asData
        ?.value;
    final playable = playableVideos(videos);
    final art = playlist.thumbnails.isNotEmpty
        ? playlist.thumbnails.last.url
        : null;
    final headerH =
        MediaQuery.sizeOf(context).height * TvMetrics.entityHeaderFraction;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TvImmersiveEntityHeader(
              imageUrl: art,
              title: playlist.name,
              subtitle: playlist.description,
              height: headerH,
              onBack: () => context.pop(),
              actions: TvEntityActionsBar(
                actions: [
                  TvEntityAction(
                    id: DetailActionId.play,
                    icon: LucideIcons.play,
                    label: l10n.playAll,
                    filled: true,
                    autofocus: true,
                    onSelect: playable.isEmpty
                        ? null
                        : () => ref
                              .read(playerStateProvider.notifier)
                              .playPlaylist(playable, startIndex: 0),
                  ),
                  TvEntityAction(
                    id: DetailActionId.shuffle,
                    icon: LucideIcons.shuffle,
                    label: l10n.shufflePlay,
                    onSelect: playable.isEmpty
                        ? null
                        : () {
                            final shuffled = List<VideoDetailed>.from(playable)
                              ..shuffle();
                            ref
                                .read(playerStateProvider.notifier)
                                .playPlaylist(shuffled, startIndex: 0);
                          },
                  ),
                  TvEntityAction(
                    id: DetailActionId.queue,
                    icon: LucideIcons.listMusic,
                    label: l10n.addToQueue,
                    onSelect: playable.isEmpty
                        ? null
                        : () => _addToQueue(context, ref, playable),
                  ),
                  TvEntityAction(
                    id: DetailActionId.save,
                    icon: liked != null
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: l10n.like,
                    active: liked != null,
                    onSelect: () {
                      ref
                          .read(libraryNotifierProvider.notifier)
                          .toggleLikedPlaylist(
                            LikedPlaylistModel(
                              playlistId: playlist.playlistId,
                              name: playlist.name,
                              thumbnailUrl: art,
                              videoCount: videos.length,
                              addedAt: DateTime.now(),
                            ),
                          );
                    },
                  ),
                ],
                onOverflow: () => ContextMenuSheet.showForPlaylist(
                  context,
                  playlistId: playlist.playlistId,
                  name: playlist.name,
                  thumbnailUrl: art,
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              8,
              TvMetrics.contentPadding,
              48,
            ),
            sliver: SliverList.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final song = videos[index];
                return TvTrackRow(
                  index: index,
                  title: song.name,
                  subtitle: displayArtists(song.artists),
                  enabled: song.isPlayable,
                  onSelect: () {
                    final start = playable.indexWhere(
                      (s) => s.videoId == song.videoId,
                    );
                    if (start < 0) return;
                    ref
                        .read(playerStateProvider.notifier)
                        .playPlaylist(playable, startIndex: start);
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
                    isVideo: true,
                    isExplicit: song.isExplicit,
                    isPlayable: song.isPlayable,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToQueue(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await ref
          .read(playPlaylistUseCaseProvider)
          .execute(videos, playIndex: -1);
      if (items.isNotEmpty) {
        await ref.read(playerStateProvider.notifier).addAllToQueue(items);
      }
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add playlist to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
      }
    }
  }
}
