import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../domain/models/library_models.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/play_podcast_use_case.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../../domain/usecases/player/start_radio_use_case.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/album/providers/album_provider.dart';
import '../../features/artist/providers/artist_provider.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/library/widgets/create_playlist_dialog.dart';
import '../../features/library/widgets/linked_playlist_actions.dart';
import '../../features/library/widgets/playlist_detail_view.dart';
import '../../features/playlist/providers/playlist_provider.dart';
import '../../features/podcast/providers/podcast_provider.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/play_podcast_use_case_provider.dart';
import '../../providers/play_playlist_use_case_provider.dart';
import '../../providers/play_video_id_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/spotify_sync_cooldown_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import 'detail_actions_bar.dart';
import 'explicit_badge.dart';
import 'thumbnail_widget.dart';

/// Whether [context] is already showing the entity identified by [paramKey]/[id]
/// (e.g. `artistId` / `albumId` on the current go_router match).
bool _isOnEntityPage(BuildContext context, String paramKey, String id) {
  try {
    return GoRouterState.of(context).pathParameters[paramKey] == id;
  } catch (_) {
    return false;
  }
}

/// Whether an action should appear given [omitActionIds] from a detail header.
bool _showAction(Set<String> omitActionIds, String id) =>
    !omitActionIds.contains(id);

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
    List<ArtistBasic>? artists,
    String? artistsJson,
    String? playCount,
    int? viewCount,
    bool isExplicit = false,
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
                    artists: artists,
                    artistsJson: artistsJson,
                    playCount: playCount,
                    viewCount: viewCount,
                    isExplicit: isExplicit,
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
            artists: artists,
            artistsJson: artistsJson,
            playCount: playCount,
            viewCount: viewCount,
            isExplicit: isExplicit,
          ),
    );
  }

  static Future<void> showForArtist(
    BuildContext context, {
    required String artistId,
    required String name,
    String? thumbnailUrl,
    String? monthlyListeners,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToArtist = _isOnEntityPage(context, 'artistId', artistId);
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
                    hideGoToArtist: hideGoToArtist,
                    omitActionIds: omitActionIds,
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
            hideGoToArtist: hideGoToArtist,
            omitActionIds: omitActionIds,
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
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToAlbum = _isOnEntityPage(context, 'albumId', albumId);
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
                    hideGoToAlbum: hideGoToAlbum,
                    omitActionIds: omitActionIds,
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
            hideGoToAlbum: hideGoToAlbum,
            omitActionIds: omitActionIds,
          ),
    );
  }

  static Future<void> showForPodcast(
    BuildContext context, {
    required String browseId,
    required String name,
    String? author,
    String? thumbnailUrl,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToPodcast = _isOnEntityPage(context, 'browseId', browseId);
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
                  child: _PodcastContextMenuSheet(
                    browseId: browseId,
                    name: name,
                    author: author,
                    thumbnailUrl: thumbnailUrl,
                    hideGoToPodcast: hideGoToPodcast,
                    omitActionIds: omitActionIds,
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
          (_) => _PodcastContextMenuSheet(
            browseId: browseId,
            name: name,
            author: author,
            thumbnailUrl: thumbnailUrl,
            hideGoToPodcast: hideGoToPodcast,
            omitActionIds: omitActionIds,
          ),
    );
  }

  static Future<void> showForEpisode(
    BuildContext context, {
    required String videoId,
    required String name,
    String? podcastName,
    String? podcastBrowseId,
    String? thumbnailUrl,
    String? date,
    void Function(String podcastBrowseId)? onGoToPodcast,
  }) {
    final hideGoToPodcast =
        podcastBrowseId != null &&
        _isOnEntityPage(context, 'browseId', podcastBrowseId);
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
                  child: _EpisodeContextMenuSheet(
                    videoId: videoId,
                    name: name,
                    podcastName: podcastName,
                    podcastBrowseId: podcastBrowseId,
                    thumbnailUrl: thumbnailUrl,
                    date: date,
                    onGoToPodcast: onGoToPodcast,
                    hideGoToPodcast: hideGoToPodcast,
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
          (_) => _EpisodeContextMenuSheet(
            videoId: videoId,
            name: name,
            podcastName: podcastName,
            podcastBrowseId: podcastBrowseId,
            thumbnailUrl: thumbnailUrl,
            date: date,
            onGoToPodcast: onGoToPodcast,
            hideGoToPodcast: hideGoToPodcast,
          ),
    );
  }

  static Future<void> showForPlaylist(
    BuildContext context, {
    required String playlistId,
    required String name,
    String? artist,
    String? thumbnailUrl,
    Set<String> omitActionIds = const {},
  }) {
    final hideGoToPlaylist = _isOnEntityPage(context, 'playlistId', playlistId);
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
                    hideGoToPlaylist: hideGoToPlaylist,
                    omitActionIds: omitActionIds,
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
            hideGoToPlaylist: hideGoToPlaylist,
            omitActionIds: omitActionIds,
          ),
    );
  }

  static Future<void> showForCustomPlaylist(
    BuildContext context, {
    required LocalPlaylistModel playlist,
    required VoidCallback onUpdated,
    bool hideGoToPlaylist = false,
    Set<String> omitActionIds = const {},
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
                    hideGoToPlaylist: hideGoToPlaylist,
                    omitActionIds: omitActionIds,
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
            hideGoToPlaylist: hideGoToPlaylist,
            omitActionIds: omitActionIds,
          ),
    );
  }

  static Future<void> showForNowPlaying(
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
    List<ArtistBasic>? artists,
    String? artistsJson,
    required void Function(String artistId) onGoToArtist,
    required void Function(String albumId) onGoToAlbum,
    bool isExplicit = false,
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
                    duration: duration,
                    isVideo: isVideo,
                    albumName: albumName,
                    artistId: artistId,
                    albumId: albumId,
                    artists: artists,
                    artistsJson: artistsJson,
                    onGoToArtist: onGoToArtist,
                    onGoToAlbum: onGoToAlbum,
                    isExplicit: isExplicit,
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
            duration: duration,
            isVideo: isVideo,
            albumName: albumName,
            artistId: artistId,
            albumId: albumId,
            artists: artists,
            artistsJson: artistsJson,
            onGoToArtist: onGoToArtist,
            onGoToAlbum: onGoToAlbum,
            isExplicit: isExplicit,
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
  final int? duration;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final List<ArtistBasic>? artists;
  final String? artistsJson;
  final void Function(String artistId) onGoToArtist;
  final void Function(String albumId) onGoToAlbum;
  final bool isExplicit;

  const _NowPlayingContextMenuSheet({
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
    required this.onGoToArtist,
    required this.onGoToAlbum,
    this.isExplicit = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

    final songAsync = ref.watch(_songFullProvider(videoId));
    final resolvedArtists = resolveArtistsList(
      artists: artists,
      artistsJson: artistsJson,
      artist: artist,
      artistId: artistId,
      enrichment: songAsync.asData?.value.artists,
    );
    final navigable = navigableArtists(resolvedArtists);
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

    ref.listen(_songFullProvider(videoId), (_, next) {
      if (next is AsyncData) {
        final data = next.value;
        if (data == null) return;
        final fullId = primaryArtistId(data.artists);
        final fullAlbumId = data.album?.albumId;
        final fullJson = encodeArtistsJson(data.artists);
        if (fullId != null || fullAlbumId != null || fullJson != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(libraryNotifierProvider.notifier)
                .updateLikedSongMetadata(
                  videoId,
                  artistId: fullId,
                  albumId: fullAlbumId,
                  artistsJson: fullJson,
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
                  if (isLoadingArtists)
                    _LoadingTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                    ),
                  if (!isLoadingArtists && navigable.length == 1)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        Navigator.pop(context);
                        onGoToArtist(navigable.first.artistId!);
                      },
                    ),
                  if (!isLoadingArtists && navigable.length > 1)
                    _ActionTile(
                      icon: LucideIcons.users,
                      label: AppLocalizations.of(context)!.goToArtists,
                      onTap: () {
                        _showArtistPicker(
                          context,
                          navigable,
                          onSelect: (id) {
                            Navigator.pop(context);
                            onGoToArtist(id);
                          },
                        );
                      },
                    ),
                  if (isLoadingAlbum)
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
                                  artistsJson:
                                      artistsJson ??
                                      encodeArtistsJson(resolvedArtists),
                                  thumbnailUrl: thumbnailUrl,
                                  isExplicit: isExplicit,
                                  isVideo: isVideo,
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
                              artistsJson:
                                  artistsJson ??
                                  encodeArtistsJson(resolvedArtists),
                              thumbnailUrl: thumbnailUrl,
                              isExplicit: isExplicit,
                              isVideo: isVideo,
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
                        artistsJson: resolvedArtistsJson,
                        thumbnailUrl: thumbnailUrl,
                        isExplicit: isExplicit,
                        duration: duration,
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
  final List<ArtistBasic>? artists;
  final String? artistsJson;
  final String? playCount;
  final int? viewCount;
  final bool isExplicit;

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
    this.artists,
    this.artistsJson,
    this.playCount,
    this.viewCount,
    this.isExplicit = false,
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

    final songAsync = ref.watch(_songFullProvider(videoId));
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
    ref.listen(_songFullProvider(videoId), (_, next) {
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
                      player.playVideoId(
                        videoId,
                        isVideo: isVideo,
                        isExplicit: isExplicit,
                      );
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
                        isExplicit: isExplicit,
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
                        isExplicit: isExplicit,
                        albumName: albumName,
                        artistId: resolvedArtistId,
                        albumId: resolvedAlbumId,
                      );
                    },
                  ),
                  if (isLoadingArtists)
                    _LoadingTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                    ),
                  if (!isLoadingArtists && navigable.length == 1)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/${navigable.first.artistId}');
                        Navigator.pop(context);
                      },
                    ),
                  if (!isLoadingArtists && navigable.length > 1)
                    _ActionTile(
                      icon: LucideIcons.users,
                      label: AppLocalizations.of(context)!.goToArtists,
                      onTap: () {
                        _showArtistPicker(
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
                    _LoadingTile(
                      icon: LucideIcons.disc,
                      label: AppLocalizations.of(context)!.goToAlbum,
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
                        artistsJson: resolvedArtistsJson,
                        thumbnailUrl: thumbnailUrl,
                        isExplicit: isExplicit,
                        duration: duration,
                      );
                    },
                  ),
                  _LikeActionTile(
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
                                  artistsJson: resolvedArtistsJson,
                                  thumbnailUrl: thumbnailUrl,
                                  isExplicit: isExplicit,
                                  isVideo: isVideo,
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
                              artistsJson: resolvedArtistsJson,
                              thumbnailUrl: thumbnailUrl,
                              isExplicit: isExplicit,
                              isVideo: isVideo,
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
  final bool hideGoToArtist;
  final Set<String> omitActionIds;

  const _ArtistContextMenuSheet({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
    this.hideGoToArtist = false,
    this.omitActionIds = const {},
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
                  if (_showAction(omitActionIds, DetailActionId.play))
                    _ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playTopSongs,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _playTopSongs(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                        );
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.shuffle))
                    _ActionTile(
                      icon: LucideIcons.shuffle,
                      label: AppLocalizations.of(context)!.shuffle,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _shufflePlay(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                        );
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.queue))
                    _ActionTile(
                      icon: LucideIcons.listMusic,
                      label: AppLocalizations.of(context)!.addToQueue,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _addTopSongsToQueue(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                        );
                      },
                    ),
                  if (!hideGoToArtist)
                    _ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$artistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.save))
                    _FollowArtistActionTile(
                      artistId: artistId,
                      name: name,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (_showAction(omitActionIds, DetailActionId.radio))
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
                  if (_showAction(omitActionIds, DetailActionId.share))
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

  Future<List<SongDetailed>> _fetchAllTopSongs(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
  ) async {
    final artist = await artistFuture;
    try {
      final songs = await repo.getArtistSongs(artistId);
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    return artist.topSongs;
  }

  Future<void> _playTopSongs(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
      if (songs.isEmpty) return;
      feedback.report('Playing $name…');
      await player.playAlbum(songs, startIndex: 0);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _shufflePlay(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
      if (songs.isEmpty) return;
      feedback.report('Shuffling $name…');
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      await player.playAlbum(shuffled, startIndex: 0);
    } catch (e) {
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _addTopSongsToQueue(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
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
  final bool hideGoToAlbum;
  final Set<String> omitActionIds;

  const _AlbumContextMenuSheet({
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
                  if (_showAction(omitActionIds, DetailActionId.play))
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
                  if (_showAction(omitActionIds, DetailActionId.shuffle))
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
                        _shuffleAlbumPlay(
                          albumFuture,
                          useCase,
                          player,
                          feedback,
                        );
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.queue))
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
                        _addAlbumToQueue(
                          albumFuture,
                          useCase,
                          player,
                          feedback,
                        );
                      },
                    ),
                  if (!hideGoToAlbum)
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
                  if (_showAction(omitActionIds, DetailActionId.save))
                    _LikeAlbumActionTile(
                      albumId: albumId,
                      name: name,
                      artistName: artist,
                      artistId: artistId,
                      thumbnailUrl: thumbnailUrl,
                      year: year,
                    ),
                  if (_showAction(omitActionIds, DetailActionId.download))
                    _ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      onTap: () {
                        final albumFuture = ref.read(
                          albumProvider(albumId).future,
                        );
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.pop(context);
                        _downloadAlbum(rootContext, ref, albumFuture, feedback);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.share))
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

  Future<void> _downloadAlbum(
    BuildContext context,
    WidgetRef ref,
    Future<AlbumFull> albumFuture,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final album = await albumFuture;
      if (album.songs.isEmpty) return;
      final notifier = ref.read(activeDownloadsProvider.notifier);
      final toDownload =
          album.songs.where((s) => !notifier.isDownloading(s.videoId)).toList();
      if (toDownload.isEmpty) {
        feedback.report(
          context.mounted
              ? (AppLocalizations.of(context)?.allSongsAlreadyDownloading ??
                  'Already downloading')
              : 'Already downloading',
        );
        return;
      }

      final alreadyDownloaded =
          ref
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
          builder:
              (ctx) => AlertDialog(
                title: Text(l10n.alreadyDownloaded),
                content: Text(
                  l10n.alreadyDownloadedSongs(
                    alreadyDownloaded.length,
                    album.name,
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

      final alreadyDownloadedIds =
          alreadyDownloaded.map((d) => d.videoId).toSet();
      final batchId = 'album:${album.albumId}';
      final batchTotal = toDownload.length;

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
            thumbnailUrl:
                song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
            subdirectory: album.name,
            isExplicit: song.isExplicit,
            batchId: batchId,
            batchName: album.name,
            batchTotal: batchTotal,
          ),
        );
      }
    } catch (e) {
      feedback.report('Failed to download: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podcast context menu
// ─────────────────────────────────────────────────────────────────────────────

class _PodcastContextMenuSheet extends ConsumerWidget {
  final String browseId;
  final String name;
  final String? author;
  final String? thumbnailUrl;
  final bool hideGoToPodcast;
  final Set<String> omitActionIds;

  const _PodcastContextMenuSheet({
    required this.browseId,
    required this.name,
    this.author,
    this.thumbnailUrl,
    this.hideGoToPodcast = false,
    this.omitActionIds = const {},
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
                      if (author != null && author!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          author!,
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
                  if (_showAction(omitActionIds, DetailActionId.play))
                    _ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playAll,
                      onTap: () {
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _playPodcast(repo, player, feedback);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.shuffle))
                    _ActionTile(
                      icon: LucideIcons.shuffle,
                      label: AppLocalizations.of(context)!.shufflePlay,
                      onTap: () {
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _shufflePodcast(repo, player, feedback);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.queue))
                    _ActionTile(
                      icon: LucideIcons.listMusic,
                      label: AppLocalizations.of(context)!.addToQueue,
                      onTap: () {
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playPodcastUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _addPodcastToQueue(repo, useCase, player, feedback);
                      },
                    ),
                  if (!hideGoToPodcast)
                    _ActionTile(
                      icon: LucideIcons.micVocal,
                      label: AppLocalizations.of(context)!.goToPodcast,
                      onTap: () {
                        context.push('/podcast/$browseId');
                        Navigator.pop(context);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.save))
                    _LikePodcastActionTile(
                      browseId: browseId,
                      name: name,
                      authorName: author,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (_showAction(omitActionIds, DetailActionId.download))
                    _ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      onTap: () {
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.pop(context);
                        _downloadPodcast(rootContext, ref, feedback);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.share))
                    _ActionTile(
                      icon: LucideIcons.share2,
                      label: AppLocalizations.of(context)!.share,
                      onTap: () {
                        Navigator.pop(context);
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'https://music.youtube.com/browse/$browseId',
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

  Future<void> _playPodcast(
    MusicRepository repo,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      feedback.report('Playing $name…');
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
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _shufflePodcast(
    MusicRepository repo,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      feedback.report('Shuffling $name…');
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
      feedback.report('Failed to play: $e');
    }
  }

  Future<void> _addPodcastToQueue(
    MusicRepository repo,
    PlayPodcastUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final podcast = await repo.getPodcast(browseId);
      final episodes =
          podcast.episodes.where((e) => e.videoId.isNotEmpty).toList();
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
        feedback.report('Added ${items.length} episodes to queue');
      }
    } catch (e) {
      feedback.report('Failed to add to queue: $e');
    }
  }

  Future<void> _downloadPodcast(
    BuildContext context,
    WidgetRef ref,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final podcast = await ref.read(podcastProvider(browseId).future);
      final notifier = ref.read(activeDownloadsProvider.notifier);
      final episodes = podcast.episodes.where((e) => e.videoId.isNotEmpty);
      final toDownload =
          episodes.where((e) => !notifier.isDownloading(e.videoId)).toList();
      if (toDownload.isEmpty) {
        feedback.report(
          context.mounted
              ? (AppLocalizations.of(context)?.allSongsAlreadyDownloading ??
                  'Already downloading')
              : 'Already downloading',
        );
        return;
      }

      final alreadyDownloaded =
          ref
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
          builder:
              (ctx) => AlertDialog(
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

      final alreadyDownloadedIds =
          alreadyDownloaded.map((d) => d.videoId).toSet();
      final batchId = 'podcast:${podcast.browseId}';
      final batchTotal = toDownload.length;

      for (final episode in toDownload) {
        if (alreadyDownloadedIds.contains(episode.videoId)) {
          await notifier.deleteDownload(episode.videoId);
        }
        unawaited(
          notifier.startDownload(
            videoId: episode.videoId,
            title: episode.name,
            artist: podcast.author?.name ?? podcast.name,
            thumbnailUrl:
                episode.thumbnails.isNotEmpty
                    ? episode.thumbnails.last.url
                    : null,
            subdirectory: podcast.name,
            isVideo: false,
            batchId: batchId,
            batchName: podcast.name,
            batchTotal: batchTotal,
          ),
        );
      }
    } catch (e) {
      feedback.report('Failed to download: $e');
    }
  }
}

class _LikePodcastActionTile extends ConsumerWidget {
  final String browseId;
  final String name;
  final String? authorName;
  final String? thumbnailUrl;

  const _LikePodcastActionTile({
    required this.browseId,
    required this.name,
    this.authorName,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPodcastProvider(browseId));
    return likedAsync.when(
      loading:
          () => ListTile(
            leading: const Icon(LucideIcons.bookmark),
            title: Text(AppLocalizations.of(context)!.follow),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSubscribed = liked != null;
        return ListTile(
          leading: Icon(
            isSubscribed ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
            color: isSubscribed ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(
            isSubscribed
                ? AppLocalizations.of(context)!.following
                : AppLocalizations.of(context)!.follow,
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

// ─────────────────────────────────────────────────────────────────────────────
// Episode context menu
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String name;
  final String? podcastName;
  final String? podcastBrowseId;
  final String? thumbnailUrl;
  final String? date;
  final void Function(String podcastBrowseId)? onGoToPodcast;
  final bool hideGoToPodcast;

  const _EpisodeContextMenuSheet({
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (podcastName != null && podcastName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          podcastName!,
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
                    label: AppLocalizations.of(context)!.playNow,
                    onTap: () {
                      final useCase = ref.read(playVideoIdUseCaseProvider);
                      final player = ref.read(playerStateProvider.notifier);
                      final feedback = ref.read(
                        actionFeedbackProvider.notifier,
                      );
                      Navigator.pop(context);
                      _playEpisode(useCase, player, feedback);
                    },
                  ),
                  if (podcastBrowseId != null && !hideGoToPodcast)
                    _ActionTile(
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
                  _LikeEpisodeActionTile(
                    videoId: videoId,
                    name: name,
                    podcastName: podcastName,
                    podcastBrowseId: podcastBrowseId,
                    thumbnailUrl: thumbnailUrl,
                    date: date,
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

  Future<void> _playEpisode(
    PlayVideoIdUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
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
      feedback.report('Failed to play: $e');
    }
  }
}

class _LikeEpisodeActionTile extends ConsumerWidget {
  final String videoId;
  final String name;
  final String? podcastName;
  final String? podcastBrowseId;
  final String? thumbnailUrl;
  final String? date;

  const _LikeEpisodeActionTile({
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
      loading:
          () => ListTile(
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
            isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
            color: isSaved ? Theme.of(context).colorScheme.primary : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Playlist context menu
// ─────────────────────────────────────────────────────────────────────────────

class _PlaylistContextMenuSheet extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? artist;
  final String? thumbnailUrl;
  final bool hideGoToPlaylist;
  final Set<String> omitActionIds;

  const _PlaylistContextMenuSheet({
    required this.playlistId,
    required this.name,
    this.artist,
    this.thumbnailUrl,
    this.hideGoToPlaylist = false,
    this.omitActionIds = const {},
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
                  if (_showAction(omitActionIds, DetailActionId.play))
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
                  if (_showAction(omitActionIds, DetailActionId.shuffle))
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
                  if (_showAction(omitActionIds, DetailActionId.queue))
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
                  if (!hideGoToPlaylist)
                    _ActionTile(
                      icon: LucideIcons.listVideo,
                      label: AppLocalizations.of(context)!.goToPlaylist,
                      onTap: () {
                        context.push('/playlist/$playlistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.save))
                    _LikePlaylistActionTile(
                      playlistId: playlistId,
                      name: name,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (_showAction(omitActionIds, DetailActionId.download))
                    _ActionTile(
                      icon: LucideIcons.download,
                      label: AppLocalizations.of(context)!.download,
                      onTap: () {
                        final videosFuture = ref.read(
                          playlistVideosProvider(playlistId).future,
                        );
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.pop(context);
                        _downloadPlaylist(
                          rootContext,
                          ref,
                          videosFuture,
                          feedback,
                        );
                      },
                    ),
                  if (_showAction(omitActionIds, DetailActionId.share))
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
      await player.playPlaylist(videos, startIndex: 0);
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
      await player.playPlaylist(shuffled, startIndex: 0);
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

  Future<void> _downloadPlaylist(
    BuildContext context,
    WidgetRef ref,
    Future<List<VideoDetailed>> videosFuture,
    ActionFeedbackNotifier feedback,
  ) async {
    try {
      final videos = await videosFuture;
      if (videos.isEmpty) return;
      final notifier = ref.read(activeDownloadsProvider.notifier);
      final toDownload =
          videos.where((v) => !notifier.isDownloading(v.videoId)).toList();
      if (toDownload.isEmpty) {
        feedback.report(
          context.mounted
              ? (AppLocalizations.of(context)?.allSongsAlreadyDownloading ??
                  'Already downloading')
              : 'Already downloading',
        );
        return;
      }

      final alreadyDownloaded =
          ref
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
          builder:
              (ctx) => AlertDialog(
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

      final alreadyDownloadedIds =
          alreadyDownloaded.map((d) => d.videoId).toSet();
      final batchId = 'playlist:$playlistId';
      final batchTotal = toDownload.length;

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
            thumbnailUrl:
                video.thumbnails.isNotEmpty ? video.thumbnails.last.url : null,
            subdirectory: name,
            isExplicit: video.isExplicit,
            isVideo: true,
            batchId: batchId,
            batchName: name,
            batchTotal: batchTotal,
          ),
        );
      }
    } catch (e) {
      feedback.report('Failed to download: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom playlist (local) context menu
// ─────────────────────────────────────────────────────────────────────────────

class _CustomPlaylistContextMenuSheet extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;
  final bool hideGoToPlaylist;
  final Set<String> omitActionIds;

  const _CustomPlaylistContextMenuSheet({
    required this.playlist,
    required this.onUpdated,
    this.hideGoToPlaylist = false,
    this.omitActionIds = const {},
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
                        playlist.isLinked
                            ? linkedSourceLabel(l10n, playlist)
                            : 'Playlist',
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
                  if (_showAction(omitActionIds, DetailActionId.play))
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
                  if (_showAction(omitActionIds, DetailActionId.shuffle))
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
                  if (_showAction(omitActionIds, DetailActionId.queue))
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
                  if (_showAction(omitActionIds, DetailActionId.rename))
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
                  if (playlist.isLinked) ...[
                    if (_showAction(omitActionIds, DetailActionId.sync))
                      _ActionTile(
                        icon: LucideIcons.refreshCw,
                        label: syncActionLabel(l10n, playlist),
                        enabled: !isSpotifySyncCoolingDown(playlist),
                        onTap: () async {
                          final container = ProviderScope.containerOf(context);
                          final strings = l10n;
                          final dialogContext =
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).context;
                          if (isSpotifySyncCoolingDown(playlist)) {
                            ref
                                .read(actionFeedbackProvider.notifier)
                                .report(strings.playlistSyncSpotifyCooldown);
                            Navigator.pop(context);
                            return;
                          }
                          Navigator.pop(context);
                          if (!dialogContext.mounted) return;
                          await syncLinkedPlaylist(
                            dialogContext,
                            container,
                            strings,
                            playlist,
                          );
                        },
                      ),
                    if (_showAction(omitActionIds, DetailActionId.unlink))
                      _ActionTile(
                        icon: LucideIcons.unlink,
                        label: l10n.unlinkPlaylist,
                        onTap: () async {
                          final container = ProviderScope.containerOf(context);
                          final unlinked = await confirmAndUnlinkPlaylist(
                            container,
                            context,
                            playlist,
                          );
                          if (unlinked && context.mounted) {
                            Navigator.pop(context);
                            onUpdated();
                          }
                        },
                      ),
                  ],
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
                  if (!hideGoToPlaylist)
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
      final items = await notifier.buildLocalPlaylistItems(
        entries,
        playIndex: 0,
      );
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
      final items = await notifier.buildLocalPlaylistItems(
        shuffled,
        playIndex: 0,
      );
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
      final items = await notifier.buildLocalPlaylistItems(
        entries,
        playIndex: -1,
      );
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
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: enabled ? onTap : null,
      enabled: enabled,
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
  final String? artistsJson;
  final bool isVideo;
  final bool isExplicit;
  final int? duration;

  const _LikeActionTile({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.artistId,
    this.albumId,
    this.artistsJson,
    this.isVideo = false,
    this.isExplicit = false,
    this.duration,
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
                    artistsJson: artistsJson,
                    addedAt: DateTime.now(),
                    isVideo: isVideo,
                    isExplicit: isExplicit,
                    duration: duration,
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

class _LikeAlbumActionTile extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artistName;
  final String? artistId;
  final String? thumbnailUrl;
  final int? year;

  const _LikeAlbumActionTile({
    required this.albumId,
    required this.name,
    required this.artistName,
    this.artistId,
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
                    artistId: artistId,
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
// Artist picker (multi-artist go-to)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showArtistPicker(
  BuildContext context,
  List<ArtistBasic> artists, {
  required void Function(String artistId) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(sheetContext)!.goToArtists,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Divider(),
            for (final a in artists)
              ListTile(
                leading: const Icon(LucideIcons.user),
                title: Text(a.name),
                dense: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelect(a.artistId!);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
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
  String? artistsJson,
  String? thumbnailUrl,
  bool isExplicit = false,
  int? duration,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder:
        (_) => _PlaylistPickerSheet(
          videoId: videoId,
          title: title,
          artist: artist,
          artistsJson: artistsJson,
          thumbnailUrl: thumbnailUrl,
          isExplicit: isExplicit,
          duration: duration,
        ),
  );
}

class _PlaylistPickerSheet extends ConsumerStatefulWidget {
  final String videoId;
  final String? title;
  final String? artist;
  final String? artistsJson;
  final String? thumbnailUrl;
  final bool isExplicit;
  final int? duration;

  const _PlaylistPickerSheet({
    required this.videoId,
    this.title,
    this.artist,
    this.artistsJson,
    this.thumbnailUrl,
    this.isExplicit = false,
    this.duration,
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
      artistsJson: widget.artistsJson,
      thumbnailUrl: widget.thumbnailUrl,
      duration: widget.duration,
      isExplicit: widget.isExplicit,
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
                                artistsJson: widget.artistsJson,
                                thumbnailUrl: widget.thumbnailUrl,
                                duration: widget.duration,
                                isExplicit: widget.isExplicit,
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
