import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/extensions/stat_format.dart';
import '../../../../core/link/sonora_link.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/start_radio_use_case_provider.dart';
import '../explicit_badge.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';
import 'pickers.dart';
import 'song_full_provider.dart';

class SongContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final List<ArtistBasic>? artists;
  final String? artistsJson;
  final String? playCount;
  final int? viewCount;
  final bool isExplicit;
  final bool isPlayable;

  const SongContextMenuSheet({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
    this.isVideo = false,
    this.albumName,
    this.artistId,
    this.albumId,
    this.artists,
    this.artistsJson,
    this.playCount,
    this.viewCount,
    this.isExplicit = false,
    this.isPlayable = true,
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
    final isOffline = ref.watch(isOfflineProvider);

    final songAsync = ref.watch(songFullProvider(videoId));
    final resolvedArtists = resolveArtistsList(
      artists: artists,
      artistsJson: artistsJson,
      artist: artist,
      artistId: artistId,
      enrichment: songAsync.asData?.value.artists,
    );
    final navigable = navigableArtists(resolvedArtists);
    final resolvedArtistId = primaryArtistId(resolvedArtists) ?? artistId;
    final resolvedAlbumId = albumId ?? songAsync.asData?.value.album?.albumId;
    final resolvedArtistsJson =
        artistsJson ?? encodeArtistsJson(resolvedArtists);
    final hasLocalArtistCredits =
        (artists != null && artists!.isNotEmpty) ||
        decodeArtistsJson(artistsJson).isNotEmpty ||
        artistId != null;
    final isLoadingArtists =
        !hasLocalArtistCredits && navigable.isEmpty && songAsync.isLoading;
    final isLoadingAlbum = albumId == null && songAsync.isLoading;
    ref.listen(songFullProvider(videoId), (_, next) {
      if (next is AsyncData &&
          (artistId == null || albumId == null || artistsJson == null)) {
        final data = next.value;
        if (data == null) return;
        final fullId = primaryArtistId(data.artists);
        final fullAlbumId = data.album?.albumId;
        final fullJson = encodeArtistsJson(data.artists);
        if (fullId != null || fullAlbumId != null || fullJson != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ref
                .read(libraryNotifierProvider.notifier)
                .updateLikedSongMetadata(
                  videoId,
                  artistId: artistId ?? fullId,
                  albumId: albumId ?? fullAlbumId,
                  artistsJson: artistsJson ?? fullJson,
                );
          });
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
                      Text.rich(
                        TextSpan(
                          children: [
                            if (isExplicit)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: ExplicitBadge(),
                                ),
                              ),
                            TextSpan(
                              text: title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
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
                          style: Theme.of(context).textTheme.labelSmall
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
                  if (isPlayable) ...[
                    ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playNow,
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(actionFeedbackProvider.notifier)
                            .report(AppLocalizations.of(context)!.playNow);
                        player.playVideoId(
                          videoId,
                          isVideo: isVideo,
                          isExplicit: isExplicit,
                        );
                      },
                    ),
                    ActionTile(
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
                          isExplicit: isExplicit,
                          albumName: albumName,
                          artistId: resolvedArtistId,
                          albumId: resolvedAlbumId,
                        );
                      },
                    ),
                    ActionTile(
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
                          isExplicit: isExplicit,
                          albumName: albumName,
                          artistId: resolvedArtistId,
                          albumId: resolvedAlbumId,
                        );
                      },
                    ),
                  ],
                  if (isLoadingArtists)
                    LoadingTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                    ),
                  if (!isLoadingArtists && navigable.length == 1)
                    ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/${navigable.first.artistId}');
                        Navigator.pop(context);
                      },
                    ),
                  if (!isLoadingArtists && navigable.length > 1)
                    ActionTile(
                      icon: LucideIcons.users,
                      label: AppLocalizations.of(context)!.goToArtists,
                      onTap: () {
                        showArtistPicker(
                          context,
                          navigable,
                          onSelect: (id) {
                            context.push('/artist/$id');
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  if (isLoadingAlbum)
                    LoadingTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                    ),
                  if (resolvedAlbumId != null)
                    ActionTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
                      onTap: () {
                        context.push('/album/$resolvedAlbumId');
                        Navigator.pop(context);
                      },
                    ),
                  if (isPlayable)
                    ActionTile(
                      icon: LucideIcons.radio,
                      label: AppLocalizations.of(context)!.startRadio,
                      enabled: !isOffline,
                      onTap: () {
                        final useCase = ref.read(startRadioUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final currentPlayer = player;
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        unawaited(
                          startSongRadio(
                            videoId: videoId,
                            useCase: useCase,
                            player: currentPlayer,
                            feedback: feedback,
                            l10n: l10n,
                          ),
                        );
                      },
                    ),
                  if (isPlayable)
                    ActionTile(
                      icon: LucideIcons.plus,
                      label: AppLocalizations.of(context)!.addToPlaylist,
                      onTap: () {
                        Navigator.pop(context);
                        showPlaylistPicker(
                          context,
                          ref,
                          videoId,
                          title: title,
                          artist: artist,
                          artistsJson: resolvedArtistsJson,
                          thumbnailUrl: thumbnailUrl,
                          isExplicit: isExplicit,
                          duration: duration,
                        );
                      },
                    ),
                  LikeActionTile(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    artistId: resolvedArtistId,
                    albumId: resolvedAlbumId,
                    artistsJson: resolvedArtistsJson,
                    isVideo: isVideo,
                    isExplicit: isExplicit,
                    duration: duration,
                    isPlayable: isPlayable,
                  ),
                  if (isPlayable)
                    ActionTile(
                      icon: isDownloaded
                          ? LucideIcons.checkCircle
                          : LucideIcons.download,
                      label: isDownloaded
                          ? AppLocalizations.of(context)!.downloaded
                          : AppLocalizations.of(context)!.download,
                      enabled: !isOffline,
                      onTap: () {
                        enqueueSingleTrackDownload(
                          sheetContext: context,
                          notifier: ref.read(activeDownloadsProvider.notifier),
                          isDownloaded: isDownloaded,
                          videoId: videoId,
                          title: title,
                          artist: artist,
                          artistsJson: resolvedArtistsJson,
                          thumbnailUrl: thumbnailUrl,
                          isExplicit: isExplicit,
                          isVideo: isVideo,
                        );
                      },
                    ),
                  ActionTile(
                    icon: LucideIcons.share2,
                    label: AppLocalizations.of(context)!.share,
                    onTap: () {
                      final share = shareSonoraLinkFromMenu(
                        ref,
                        context,
                        link: SonoraLink(
                          kind: SonoraLinkKind.track,
                          id: videoId,
                        ),
                        title: title,
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
}
