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
import '../../../artist/providers/artist_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_actions_bar.dart';
import '../../widgets/tv_track_row.dart';

class TvArtistScreen extends ConsumerWidget {
  final String artistId;

  const TvArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistProvider(artistId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
      ),
      data: (artist) => _TvArtistBody(artist: artist),
    );
  }
}

class _TvArtistBody extends ConsumerWidget {
  final ArtistFull artist;

  const _TvArtistBody({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(isOfflineProvider);
    final followed = ref
        .watch(followedArtistProvider(artist.artistId))
        .asData
        ?.value;
    final playable = playableSongs(artist.topSongs);
    final art = artist.thumbnails.isNotEmpty
        ? artist.thumbnails.last.url
        : null;
    final headerH =
        MediaQuery.sizeOf(context).height * TvMetrics.entityHeaderFraction;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TvImmersiveEntityHeader(
              imageUrl: art,
              title: artist.name,
              description: artist.description,
              height: headerH,
              onBack: () => context.pop(),
              actions: TvEntityActionsBar(
                actions: [
                  TvEntityAction(
                    id: DetailActionId.play,
                    icon: LucideIcons.play,
                    label: l10n.playTopSongs,
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
                    icon: followed != null
                        ? LucideIcons.userCheck
                        : LucideIcons.userPlus,
                    label: followed != null ? l10n.following : l10n.follow,
                    active: followed != null,
                    onSelect: () {
                      ref
                          .read(libraryNotifierProvider.notifier)
                          .toggleFollowedArtist(
                            FollowedArtistModel(
                              artistId: artist.artistId,
                              name: artist.name,
                              thumbnailUrl: art,
                              addedAt: DateTime.now(),
                            ),
                          );
                    },
                  ),
                ],
                onOverflow: () => ContextMenuSheet.showForArtist(
                  context,
                  artistId: artist.artistId,
                  name: artist.name,
                  thumbnailUrl: art,
                  omitActionIds: {
                    DetailActionId.play,
                    DetailActionId.shuffle,
                    DetailActionId.queue,
                    DetailActionId.save,
                    DetailActionId.share,
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
              itemCount: artist.topSongs.length,
              itemBuilder: (context, index) {
                final song = artist.topSongs[index];
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
                    artistId: artist.artistId,
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
      debugPrint('Failed to add artist songs to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
      }
    }
  }
}
