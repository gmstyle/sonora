import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/extensions/stat_format.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import 'thumbnail_widget.dart';

import '../../features/library/widgets/create_playlist_dialog.dart';
import '../../../l10n/app_localizations.dart';

class ContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final String? playCount;
  final int? viewCount;

  const ContextMenuSheet({
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
    this.playCount,
    this.viewCount,
  });

  static Future<void> show(
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
    String? playCount,
    int? viewCount,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => ContextMenuSheet(
            videoId: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            isVideo: isVideo,
            albumName: albumName,
            artistId: artistId,
            albumId: albumId,
            playCount: playCount,
            viewCount: viewCount,
          ),
    );
  }

  String? _formatStat() {
    if (playCount != null && playCount!.isNotEmpty) return stripYtLabel(playCount);
    if (viewCount != null) return viewCount!.toCompact();
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);

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
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    icon: Icons.play_arrow,
                    label: AppLocalizations.of(context)!.playNow,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(actionFeedbackProvider.notifier).report(AppLocalizations.of(context)!.playNow);
                      player.playVideoId(videoId);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.playlist_play,
                    label: AppLocalizations.of(context)!.playNext,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(actionFeedbackProvider.notifier).report(AppLocalizations.of(context)!.playNext);
                      player.playNextVideoId(
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        durationSec: duration,
                        isVideo: isVideo,
                        albumName: albumName,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.queue_music,
                    label: AppLocalizations.of(context)!.addToQueue,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(actionFeedbackProvider.notifier).report(AppLocalizations.of(context)!.addToQueue);
                      player.addToQueueVideoId(
                        videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        durationSec: duration,
                        isVideo: isVideo,
                        albumName: albumName,
                      );
                    },
                  ),
                  if (artistId != null)
                    _ActionTile(
                      icon: Icons.person,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$artistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (albumId != null)
                    _ActionTile(
                      icon: Icons.album,
                      label: AppLocalizations.of(context)!.goToAlbum,
                      onTap: () {
                        context.push('/album/$albumId');
                        Navigator.pop(context);
                      },
                    ),
                  _ActionTile(
                    icon: Icons.radio,
                    label: AppLocalizations.of(context)!.startRadio,
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final useCase = ref.read(startRadioUseCaseProvider);
                        final result = await useCase.execute(videoId);
                        await player.playNow([result.firstItem]);
                        if (result.remaining.isNotEmpty) {
                          final pendingItems = useCase.toPendingItems(
                            result.remaining,
                          );
                          player.addAllToQueue(pendingItems);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.failedToStartRadio),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _ActionTile(
                    icon: Icons.playlist_add,
                    label: AppLocalizations.of(context)!.addToPlaylist,
                    onTap: () {
                      Navigator.pop(context);
                      _showPlaylistPicker(context, ref, videoId);
                    },
                  ),
                  _LikeActionTile(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                  ),
                  _ActionTile(
                    icon: isDownloaded ? Icons.check_circle : Icons.download,
                    label: isDownloaded ? AppLocalizations.of(context)!.downloaded : AppLocalizations.of(context)!.download,
                    onTap: () {
                      Navigator.pop(context);
                      if (isDownloaded) {
                        showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text(AppLocalizations.of(context)!.alreadyDownloaded),
content: Text(
                                  AppLocalizations.of(context)!.alreadyDownloadedConfirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(AppLocalizations.of(context)!.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(AppLocalizations.of(context)!.continueAction),
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
                                  thumbnailUrl: thumbnailUrl,
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
                              thumbnailUrl: thumbnailUrl,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.downloadStarted)),
                        );
                      }
                    },
                  ),
                  _ActionTile(
                    icon: Icons.share,
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
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      dense: true,
    );
  }
}

class _LikeActionTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;

  const _LikeActionTile({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading:
          () => ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text(AppLocalizations.of(context)!.like),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(isLiked ? AppLocalizations.of(context)!.unlike : AppLocalizations.of(context)!.like),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedSong(
                  LikedSongModel(
                    videoId: videoId,
                    title: title,
                    artist: artist,
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

Future<void> _showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  String videoId,
) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (_) => _PlaylistPickerSheet(videoId: videoId),
  );
}

class _PlaylistPickerSheet extends ConsumerStatefulWidget {
  final String videoId;

  const _PlaylistPickerSheet({required this.videoId});

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
    await notifier.addEntryToPlaylist(created.id, widget.videoId);
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
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.of(context)!.createNewPlaylist),
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
                              SnackBar(content: Text(AppLocalizations.of(context)!.addedTo(name))),
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
                        leading: const Icon(Icons.playlist_play),
                        title: Text(playlist.name),
                        onTap: () async {
                          await ref
                              .read(libraryNotifierProvider.notifier)
                              .addEntryToPlaylist(playlist.id, widget.videoId);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.addedToPlaylist(playlist.name)),
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
