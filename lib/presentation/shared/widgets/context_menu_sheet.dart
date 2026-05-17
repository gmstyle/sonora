import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/library_models.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';

class ContextMenuSheet extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;

  const ContextMenuSheet({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
    this.isVideo = false,
    this.albumName,
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
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerStateProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child:
                      thumbnailUrl != null
                          ? Image.network(
                            thumbnailUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, _, _) => Container(
                                  width: 48,
                                  height: 48,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                ),
                          )
                          : Container(
                            width: 48,
                            height: 48,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.music_note),
                          ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _ActionTile(
            icon: Icons.play_arrow,
            label: 'Play Now',
            onTap: () {
              Navigator.pop(context);
              player.playVideoId(videoId);
            },
          ),
          _ActionTile(
            icon: Icons.playlist_play,
            label: 'Play Next',
            onTap: () {
              Navigator.pop(context);
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
            label: 'Add to Queue',
            onTap: () {
              Navigator.pop(context);
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
          _ActionTile(
            icon: Icons.playlist_add,
            label: 'Add to Playlist',
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
            icon: Icons.download,
            label: 'Download',
            onTap: () {
              Navigator.pop(context);
              ref.read(activeDownloadsProvider.notifier).startDownload(
                videoId: videoId,
                title: title,
                artist: artist,
                thumbnailUrl: thumbnailUrl,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download started')),
              );
            },
          ),
          _ActionTile(
            icon: Icons.share,
            label: 'Share',
            onTap: () {
              Navigator.pop(context);
              SharePlus.instance.share(
                ShareParams(text: 'https://music.youtube.com/watch?v=$videoId'),
              );
            },
          ),
          const SizedBox(height: 8),
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
          () => const ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text('Like'),
            enabled: false,
            dense: true,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color:
                isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(isLiked ? 'Unlike' : 'Like'),
          onTap: () async {
            await ref.read(libraryNotifierProvider.notifier).toggleLikedSong(
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
    _playlistsFuture = ref
        .read(libraryNotifierProvider.notifier)
        .getAllPlaylists();
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
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No playlists yet. Create one in Library.'),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Add to Playlist',
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
                              .addEntryToPlaylist(
                                playlist.id,
                                widget.videoId,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to "${playlist.name}"'),
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
