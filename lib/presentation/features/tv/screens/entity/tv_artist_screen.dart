import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/extensions/stat_format.dart';
import '../../../../../core/utils/artists_utils.dart';
import '../../../../../core/utils/playable_tracks.dart';
import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/play_album_use_case_provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/start_radio_use_case_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/detail_actions_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../artist/providers/artist_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_side_column.dart';
import '../../widgets/tv_entity_format.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_poster_card.dart';
import '../../widgets/tv_shelf.dart';
import '../../widgets/tv_shimmer.dart';
import '../../widgets/tv_track_row.dart';

class TvArtistScreen extends ConsumerWidget {
  final String artistId;

  const TvArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistProvider(artistId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () => const TvEntityShimmer(circleArtwork: true),
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

class _TvArtistBody extends ConsumerStatefulWidget {
  final ArtistFull artist;

  const _TvArtistBody({required this.artist});

  @override
  ConsumerState<_TvArtistBody> createState() => _TvArtistBodyState();
}

class _TvArtistBodyState extends ConsumerState<_TvArtistBody> {
  final FocusNode _playAllFocus = FocusNode(debugLabel: 'tvArtistPlayAll');

  @override
  void dispose() {
    _playAllFocus.dispose();
    super.dispose();
  }

  Future<List<SongDetailed>> _resolveAllTopSongs(ArtistFull artist) async {
    try {
      final songs = await ref.read(artistSongsProvider(artist.artistId).future);
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    return artist.topSongs;
  }

  Future<void> _playTopSongs(ArtistFull artist) async {
    final songs = playableSongs(await _resolveAllTopSongs(artist));
    if (!mounted || songs.isEmpty) return;
    await ref
        .read(playerStateProvider.notifier)
        .playAlbum(songs, startIndex: 0);
  }

  Future<void> _shuffleTopSongs(ArtistFull artist) async {
    final l10n = AppLocalizations.of(context)!;
    final player = ref.read(playerStateProvider.notifier);
    try {
      if (artist.shuffleId != null && artist.shuffleId!.isNotEmpty) {
        final useCase = ref.read(startRadioUseCaseProvider);
        final seed = artist.topSongs.isNotEmpty
            ? artist.topSongs.first.videoId
            : '';
        final result = await useCase.execute(
          seed,
          playlistId: artist.shuffleId,
          radio: false,
          shuffle: true,
        );
        if (!mounted) return;
        await player.playNow([result.firstItem]);
        if (result.remaining.isNotEmpty) {
          player.addAllToQueue(useCase.toPendingItems(result.remaining));
        }
        return;
      }

      final songs = playableSongs(await _resolveAllTopSongs(artist));
      if (!mounted || songs.isEmpty) return;
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      await player.playAlbum(shuffled, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to shuffle artist: $e');
      if (mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToPlay, kind: FeedbackKind.error);
      }
    }
  }

  Future<void> _playFromTrack(
    ArtistFull artist,
    SongDetailed song,
    List<SongDetailed> previewPlayable,
  ) async {
    final resolved = playableSongs(await _resolveAllTopSongs(artist));
    if (!mounted) return;
    final start = resolved.indexWhere((s) => s.videoId == song.videoId);
    if (start >= 0) {
      await ref
          .read(playerStateProvider.notifier)
          .playAlbum(resolved, startIndex: start);
      return;
    }
    final fallbackStart = previewPlayable.indexWhere(
      (s) => s.videoId == song.videoId,
    );
    if (fallbackStart < 0) return;
    await ref
        .read(playerStateProvider.notifier)
        .playAlbum(previewPlayable, startIndex: fallbackStart);
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final offline = ref.watch(isOfflineProvider);
    final followed = ref
        .watch(followedArtistProvider(artist.artistId))
        .asData
        ?.value;
    final playingVideoId = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.id),
    );
    final playable = playableSongs(artist.topSongs);
    final art = artist.thumbnails.isNotEmpty
        ? artist.thumbnails.last.url
        : null;

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
              TvEntitySideColumn(
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
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
                      size: 160,
                      shape: ThumbnailShape.circle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    artist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: TvColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  TvArtistStats(artist: artist),
                  if (artist.description != null &&
                      artist.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      artist.description!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: TvColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 224,
                    child: Column(
                      children: [
                        TvFocusable(
                          focusNode: _playAllFocus,
                          autofocus: true,
                          onSelect: playable.isEmpty
                              ? null
                              : () => _playTopSongs(artist),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
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
                                  l10n.playTopSongs,
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
                              : () => _shuffleTopSongs(artist),
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
                                  style: theme.textTheme.labelMedium?.copyWith(
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
                                      .toggleFollowedArtist(
                                        FollowedArtistModel(
                                          artistId: artist.artistId,
                                          name: artist.name,
                                          thumbnailUrl: art,
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
                                    color: followed != null
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.16,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: followed != null
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.4,
                                            )
                                          : TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        followed != null
                                            ? LucideIcons.userCheck
                                            : LucideIcons.userPlus,
                                        size: 15,
                                        color: followed != null
                                            ? colorScheme.primary
                                            : TvColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        followed != null
                                            ? l10n.following
                                            : l10n.follow,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: followed != null
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
                                  : () => _addToQueue(context, artist),
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
                              onSelect: () => ContextMenuSheet.showForArtist(
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
              const SizedBox(width: 32),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              l10n.topSongs.toUpperCase(),
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
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, color: TvColors.border),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final song = artist.topSongs[index];
                          final albumName = song.album?.name;
                          final subtitle =
                              (albumName != null && albumName.isNotEmpty)
                              ? albumName
                              : displayArtists(song.artists);
                          return TvTrackRow(
                            index: index,
                            title: song.name,
                            subtitle: subtitle,
                            duration: formatTrackDuration(song.duration),
                            playCount: formatPlayCount(song.playCount),
                            isExplicit: song.isExplicit,
                            isPlaying: playingVideoId == song.videoId,
                            enabled: song.isPlayable,
                            onLeftAtEdge: () => _playAllFocus.requestFocus(),
                            onSelect: () =>
                                _playFromTrack(artist, song, playable),
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
                              playCount: song.playCount,
                            ),
                          );
                        }, childCount: artist.topSongs.length),
                      ),
                    ),
                    if (artist.topAlbums.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TvShelf(
                          title: l10n.albums,
                          children: [
                            for (final album in artist.topAlbums)
                              TvPosterCard(
                                title: album.name,
                                subtitle: [
                                  displayArtists(album.artists),
                                  if (album.year != null) '${album.year}',
                                ].where((s) => s.isNotEmpty).join(' • '),
                                imageUrl: album.thumbnails.isNotEmpty
                                    ? album.thumbnails.last.url
                                    : null,
                                onSelect: () =>
                                    context.push('/album/${album.albumId}'),
                                onLongSelect: () =>
                                    ContextMenuSheet.showForAlbum(
                                      context,
                                      albumId: album.albumId,
                                      name: album.name,
                                      artist: displayArtists(album.artists),
                                      artistId: primaryArtistId(album.artists),
                                      thumbnailUrl: album.thumbnails.isNotEmpty
                                          ? album.thumbnails.last.url
                                          : null,
                                      year: album.year,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    if (artist.topSingles.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TvShelf(
                          title: l10n.singles,
                          children: [
                            for (final single in artist.topSingles)
                              TvPosterCard(
                                title: single.name,
                                subtitle: [
                                  displayArtists(single.artists),
                                  if (single.year != null) '${single.year}',
                                ].where((s) => s.isNotEmpty).join(' • '),
                                imageUrl: single.thumbnails.isNotEmpty
                                    ? single.thumbnails.last.url
                                    : null,
                                onSelect: () =>
                                    context.push('/album/${single.albumId}'),
                                onLongSelect: () =>
                                    ContextMenuSheet.showForAlbum(
                                      context,
                                      albumId: single.albumId,
                                      name: single.name,
                                      artist: displayArtists(single.artists),
                                      artistId: primaryArtistId(single.artists),
                                      thumbnailUrl: single.thumbnails.isNotEmpty
                                          ? single.thumbnails.last.url
                                          : null,
                                      year: single.year,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    if (artist.topVideos.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TvShelf(
                          title: l10n.videos,
                          children: [
                            for (final video in artist.topVideos)
                              TvPosterCard(
                                title: video.name,
                                subtitle: [
                                  displayArtists(video.artists),
                                  ?formatPlayCount(video.viewCount),
                                ].where((s) => s.isNotEmpty).join(' • '),
                                imageUrl: video.thumbnails.isNotEmpty
                                    ? video.thumbnails.last.url
                                    : null,
                                onSelect: video.isPlayable
                                    ? () => ref
                                          .read(playerStateProvider.notifier)
                                          .playVideoId(
                                            video.videoId,
                                            isVideo: true,
                                            isExplicit: video.isExplicit,
                                          )
                                    : null,
                                onLongSelect: () =>
                                    ContextMenuSheet.showForSong(
                                      context,
                                      videoId: video.videoId,
                                      title: video.name,
                                      artist: displayArtists(video.artists),
                                      artists: video.artists,
                                      thumbnailUrl: video.thumbnails.isNotEmpty
                                          ? video.thumbnails.last.url
                                          : null,
                                      duration: video.duration,
                                      isVideo: true,
                                      isExplicit: video.isExplicit,
                                      isPlayable: video.isPlayable,
                                      artistId: artist.artistId,
                                      playCount: video.viewCount,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    if (artist.similarArtists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TvShelf(
                          title: l10n.similarArtists,
                          children: [
                            for (final similar in artist.similarArtists)
                              TvPosterCard(
                                title: similar.name,
                                subtitle: statFigure(similar.monthlyListeners),
                                imageUrl: similar.thumbnails.isNotEmpty
                                    ? similar.thumbnails.last.url
                                    : null,
                                shape: ThumbnailShape.circle,
                                onSelect: () =>
                                    context.push('/artist/${similar.artistId}'),
                                onLongSelect: () =>
                                    ContextMenuSheet.showForArtist(
                                      context,
                                      artistId: similar.artistId,
                                      name: similar.name,
                                      thumbnailUrl:
                                          similar.thumbnails.isNotEmpty
                                          ? similar.thumbnails.last.url
                                          : null,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    if (artist.featuredOn.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TvShelf(
                          title: l10n.featuredOn,
                          children: [
                            for (final playlist in artist.featuredOn)
                              TvPosterCard(
                                title: playlist.name,
                                subtitle: displayArtists(playlist.artists),
                                imageUrl: playlist.thumbnails.isNotEmpty
                                    ? playlist.thumbnails.last.url
                                    : null,
                                onSelect: () => context.push(
                                  '/playlist/${playlist.playlistId}',
                                ),
                                onLongSelect: () =>
                                    ContextMenuSheet.showForPlaylist(
                                      context,
                                      playlistId: playlist.playlistId,
                                      name: playlist.name,
                                      thumbnailUrl:
                                          playlist.thumbnails.isNotEmpty
                                          ? playlist.thumbnails.last.url
                                          : null,
                                    ),
                              ),
                          ],
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

  Future<void> _addToQueue(BuildContext context, ArtistFull artist) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final songs = playableSongs(await _resolveAllTopSongs(artist));
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
