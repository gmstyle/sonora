import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';

import '../../../../domain/models/library_models.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../providers/library_provider.dart';

class PlaylistDetailView extends ConsumerStatefulWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const PlaylistDetailView({
    super.key,
    required this.playlist,
    required this.onUpdated,
  });

  @override
  ConsumerState<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends ConsumerState<PlaylistDetailView> {
  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(playlistEntriesProvider(widget.playlist.id));
    final likedAsync = ref.watch(likedSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: AppLocalizations.of(context)!.playAll,
            onPressed: () => _playAll(),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: AppLocalizations.of(context)!.shufflePlay,
            onPressed: () => _shufflePlay(),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading:
            () => ListView.builder(
              itemCount: 8,
              padding: const EdgeInsets.only(top: 8),
              itemBuilder:
                  (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
            ),
        error:
            (e, _) => ErrorRetryWidget(
              message:
                  AppLocalizations.of(context)!.failedToLoadPlaylistEntries,
              onRetry:
                  () => ref.invalidate(
                    playlistEntriesProvider(widget.playlist.id),
                  ),
            ),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.playlist_play,
              title: AppLocalizations.of(context)!.emptyPlaylist,
              body: AppLocalizations.of(context)!.emptyPlaylistHint,
            );
          }

          final likedSongs = likedAsync.asData?.value ?? <LikedSongModel>[];

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: entries.length,
            onReorderItem:
                (oldIndex, newIndex) => _reorder(entries, oldIndex, newIndex),
            itemBuilder: (_, i) {
              final entry = entries[i];
              final liked = _findLiked(likedSongs, entry.videoId);
              final title =
                  liked?.title ?? entry.title ?? 'Video #${entry.videoId}';
              final artist = liked?.artist ?? entry.artist ?? '';

              return ListTile(
                key: ValueKey('${entry.playlistId}-${entry.videoId}'),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: artist.isNotEmpty ? Text(artist) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeEntry(entry),
                    ),
                  ],
                ),
                onTap: () => _playFrom(entries, i),
              );
            },
          );
        },
      ),
    );
  }

  LikedSongModel? _findLiked(List<LikedSongModel> songs, String videoId) {
    for (final s in songs) {
      if (s.videoId == videoId) return s;
    }
    return null;
  }

  Future<void> _removeEntry(PlaylistEntryModel entry) async {
    await ref
        .read(libraryNotifierProvider.notifier)
        .removeEntry(entry.playlistId, entry.videoId);
    ref.invalidate(playlistEntriesProvider(widget.playlist.id));
    widget.onUpdated();
  }

  Future<void> _reorder(
    List<PlaylistEntryModel> entries,
    int oldIndex,
    int newIndex,
  ) async {
    final items = List<PlaylistEntryModel>.from(entries);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    await ref
        .read(libraryNotifierProvider.notifier)
        .reorderPlaylistEntries(widget.playlist.id, items);
    ref.invalidate(playlistEntriesProvider(widget.playlist.id));
  }

  Future<void> _playAll() async {
    final entries = await ref.read(
      playlistEntriesProvider(widget.playlist.id).future,
    );
    await _buildMediaItemsAndPlay(entries, startIndex: 0);
  }

  Future<void> _shufflePlay() async {
    final entries = await ref.read(
      playlistEntriesProvider(widget.playlist.id).future,
    );
    final shuffled = List<PlaylistEntryModel>.from(entries)..shuffle();
    await _buildMediaItemsAndPlay(shuffled, startIndex: 0);
  }

  Future<void> _playFrom(List<PlaylistEntryModel> entries, int index) async {
    await _buildMediaItemsAndPlay(entries, startIndex: index);
  }

  Future<void> _buildMediaItemsAndPlay(
    List<PlaylistEntryModel> entries, {
    required int startIndex,
  }) async {
    final player = ref.read(playerStateProvider.notifier);
    final items = await ref
        .read(libraryNotifierProvider.notifier)
        .buildLocalPlaylistItems(entries);
    await player.playNow(items, initialIndex: startIndex);
  }
}
