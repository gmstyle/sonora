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
                  name: p.name,
                  description: p.description,
                  thumbnailUrl: null,
                  onTap: () => _showPlaylistDetail(context, p),
                  onLongPress:
                      () => ContextMenuSheet.showForPlaylist(
                        context,
                        playlistId: p.id.toString(),
                        name: p.name,
                        thumbnailUrl: null,
                      ),
                );
              }, childCount: playlists.length),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final p = playlists[i];
              return Dismissible(
                key: ValueKey(p.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(
                    LucideIcons.trash2,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: Text(
                            AppLocalizations.of(context)!.deletePlaylist,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.deletePlaylistConfirm(p.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(AppLocalizations.of(context)!.delete),
                            ),
                          ],
                        ),
                  );
                },
                onDismissed: (_) async {
                  await ref
                      .read(libraryNotifierProvider.notifier)
                      .deletePlaylist(p.id);
                  ref.invalidate(playlistsProvider);
                },
                child: ListTile(
                  leading: const Icon(LucideIcons.listVideo),
                  title: Text(p.name),
                  subtitle:
                      p.description != null && p.description!.isNotEmpty
                          ? Text(
                            p.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil),
                        onPressed: () => _renamePlaylist(context, p),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () => _deletePlaylist(context, p),
                      ),
                      const Icon(LucideIcons.chevronRight),
                    ],
                  ),
                  onTap: () => _showPlaylistDetail(context, p),
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
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

  Future<void> _deletePlaylist(
    BuildContext context,
    LocalPlaylistModel playlist,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.deletePlaylist),
            content: Text(
              AppLocalizations.of(
                context,
              )!.deletePlaylistConfirm(playlist.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref
          .read(libraryNotifierProvider.notifier)
          .deletePlaylist(playlist.id);
      ref.invalidate(playlistsProvider);
    }
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    LocalPlaylistModel playlist,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => CreatePlaylistDialog(
            initialName: playlist.name,
            title: AppLocalizations.of(context)!.renamePlaylist,
          ),
    );
    if (result != null && result.isNotEmpty && result != playlist.name) {
      await ref
          .read(libraryNotifierProvider.notifier)
          .updatePlaylist(playlist.id, name: result);
      ref.invalidate(playlistsProvider);
    }
  }
}

class _LocalPlaylistCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LocalPlaylistCard({
    required this.name,
    this.description,
    this.thumbnailUrl,
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
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 150,
              shape: ThumbnailShape.rounded,
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

class _ShimmerPlaylistList extends StatelessWidget {
  const _ShimmerPlaylistList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
