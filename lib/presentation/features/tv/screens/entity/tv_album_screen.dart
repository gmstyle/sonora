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
import '../../../album/providers/album_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_actions_bar.dart';
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

class _TvAlbumBody extends ConsumerWidget {
  final AlbumFull album;

  const _TvAlbumBody({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(isOfflineProvider);
    final liked = ref.watch(likedAlbumProvider(album.albumId)).asData?.value;
    final playable = playableSongs(album.songs);
    final art = album.thumbnails.isNotEmpty ? album.thumbnails.last.url : null;
    final headerH =
        MediaQuery.sizeOf(context).height * TvMetrics.entityHeaderFraction;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TvImmersiveEntityHeader(
              imageUrl: art,
              eyebrow: album.year?.toString(),
              title: album.name,
              subtitle: displayArtists(album.artists),
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
                              .playAlbum(playable, startIndex: 0),
                  ),
                  TvEntityAction(
                    id: DetailActionId.shuffle,
                    icon: LucideIcons.shuffle,
                    label: l10n.shufflePlay,
                    onSelect: playable.isEmpty
                        ? null
                        : () {
                            final shuffled = List<SongDetailed>.from(playable)
                              ..shuffle();
                            ref
                                .read(playerStateProvider.notifier)
                                .playAlbum(shuffled, startIndex: 0);
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
                          .toggleLikedAlbum(
                            LikedAlbumModel(
                              albumId: album.albumId,
                              name: album.name,
                              artistName: displayArtists(album.artists),
                              artistId: primaryArtistId(album.artists),
                              thumbnailUrl: art,
                              year: album.year,
                              addedAt: DateTime.now(),
                            ),
                          );
                    },
                  ),
                ],
                onOverflow: () => ContextMenuSheet.showForAlbum(
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
              itemCount: album.songs.length,
              itemBuilder: (context, index) {
                final song = album.songs[index];
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
