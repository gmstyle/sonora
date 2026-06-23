import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/playlist_cover_collage.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/library_provider.dart';
import 'create_playlist_dialog.dart';
import 'playlist_detail_view.dart';

class PlaylistsTab extends ConsumerStatefulWidget {
  const PlaylistsTab({super.key});

  @override
  ConsumerState<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<PlaylistsTab> {
  @override
  void initState() {
    super.initState();
    Future(
      () =>
          ref
              .read(libraryNotifierProvider.notifier)
              .refreshPlaylistThumbnailsIfNeeded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(sortedPlaylistsProvider);
    final likedAsync = ref.watch(sortedLikedPlaylistsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;

    if (myAsync.isLoading || likedAsync.isLoading) {
      return const _ShimmerPlaylistList();
    }
    if (myAsync.hasError) {
      return ErrorRetryWidget(
        message: AppLocalizations.of(context)!.failedToLoadPlaylists,
        onRetry: () => ref.invalidate(playlistsProvider),
      );
    }
    if (likedAsync.hasError) {
      return ErrorRetryWidget(
        message: AppLocalizations.of(context)!.failedToLoadLikedPlaylists,
        onRetry: () => ref.invalidate(likedPlaylistsProvider),
      );
    }

    final playlists = myAsync.value ?? [];
    final liked = likedAsync.value ?? [];

    final gridDelegate =
        isMobile
            ? const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.68,
            )
            : const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170.0,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.68,
            );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.myPlaylists,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton.filled(
                  icon: const Icon(LucideIcons.plus),
                  tooltip: AppLocalizations.of(context)!.createPlaylist,
                  onPressed: () => _createPlaylist(context),
                ),
              ],
            ),
          ),
        ),
        if (playlists.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.noLocalPlaylistsYet,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate((_, i) {
                final p = playlists[i];
                return _LocalPlaylistCard(
                  playlistId: p.id,
                  name: p.name,
                  description: p.description,
                  onTap: () => _showPlaylistDetail(context, p),
                  onLongPress:
                      () => ContextMenuSheet.showForCustomPlaylist(
                        context,
                        playlist: p,
                        onUpdated: () => ref.invalidate(playlistsProvider),
                      ),
                );
              }, childCount: playlists.length),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final p = playlists[i];
              return _LocalPlaylistTile(
                playlist: p,
                onTap: () => _showPlaylistDetail(context, p),
                onLongPress:
                    () => ContextMenuSheet.showForCustomPlaylist(
                      context,
                      playlist: p,
                      onUpdated: () => ref.invalidate(playlistsProvider),
                    ),
              );
            }, childCount: playlists.length),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.likedPlaylists,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (liked.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.likePlaylistHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate((_, i) {
                final p = liked[i];
                return PlaylistCard(
                  playlistId: p.playlistId,
                  name: p.name,
                  thumbnailUrl: p.thumbnailUrl,
                  artist:
                      p.videoCount != null ? '${p.videoCount} videos' : null,
                );
              }, childCount: liked.length),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final p = liked[i];
              return Dismissible(
                key: ValueKey(p.playlistId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(
                    LucideIcons.heart,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                onDismissed: (_) async {
                  await ref
                      .read(libraryNotifierProvider.notifier)
                      .toggleLikedPlaylist(p);
                },
                child: ListTile(
                  leading: ThumbnailWidget(
                    imageUrl: p.thumbnailUrl,
                    size: 48,
                    shape: ThumbnailShape.rounded,
                  ),
                  title: Text(p.name),
                  subtitle:
                      p.videoCount != null
                          ? Text('${p.videoCount} videos')
                          : null,
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/playlist/${p.playlistId}'),
                  onLongPress:
                      () => ContextMenuSheet.showForPlaylist(
                        context,
                        playlistId: p.playlistId,
                        name: p.name,
                        thumbnailUrl: p.thumbnailUrl,
                      ),
                ),
              );
            }, childCount: liked.length),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ),
      ],
    );
  }

  void _showPlaylistDetail(BuildContext context, LocalPlaylistModel playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlaylistDetailView(
              playlist: playlist,
              onUpdated: () {
                ref.invalidate(playlistsProvider);
              },
            ),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const CreatePlaylistDialog(),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(libraryNotifierProvider.notifier).createPlaylist(result);
      ref.invalidate(playlistsProvider);
    }
  }
}

class _PlaylistCoverBuilder extends ConsumerWidget {
  final int playlistId;
  final double size;

  const _PlaylistCoverBuilder({required this.playlistId, this.size = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(playlistEntriesProvider(playlistId));
    final likedSongs = ref.watch(likedSongsProvider).asData?.value ?? [];

    final urls = switch (entriesAsync) {
      AsyncData(:final value) =>
        value
            .map((e) {
              final liked = likedSongs.cast<LikedSongModel?>().firstWhere(
                (l) => l?.videoId == e.videoId,
                orElse: () => null,
              );
              return liked?.thumbnailUrl ?? e.thumbnailUrl;
            })
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .take(3)
            .toList(),
      _ => <String>[],
    };

    return SizedBox(
      width: size,
      height: size,
      child: PlaylistCoverCollage(thumbnailUrls: urls),
    );
  }
}

class _LocalPlaylistCard extends StatelessWidget {
  final int playlistId;
  final String name;
  final String? description;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LocalPlaylistCard({
    required this.playlistId,
    required this.name,
    this.description,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'local_playlist_art_$playlistId',
              child: _PlaylistCoverBuilder(playlistId: playlistId, size: 150),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                description!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalPlaylistTile extends StatelessWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LocalPlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _PlaylistCoverBuilder(playlistId: playlist.id, size: 48),
      title: Text(playlist.name),
      subtitle:
          playlist.description != null && playlist.description!.isNotEmpty
              ? Text(
                playlist.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
              : null,
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _ShimmerPlaylistList extends StatelessWidget {
  const _ShimmerPlaylistList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
