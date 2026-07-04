import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/library_provider.dart';

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sortedLikedAlbumsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;

    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadAlbums,
            onRetry: () => ref.invalidate(likedAlbumsProvider),
          ),
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.disc,
            title: AppLocalizations.of(context)!.noLikedAlbums,
            body: AppLocalizations.of(context)!.noLikedAlbumsHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedAlbumsProvider.future),
          child:
              isGridView
                  ? GridView.builder(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    gridDelegate:
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
                            ),
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final a = albums[i];
                      return AlbumCard(
                        albumId: a.albumId,
                        name: a.name,
                        artist: a.artistName,
                        artistId: a.artistId,
                        thumbnailUrl: a.thumbnailUrl,
                        year: a.year,
                      );
                    },
                  )
                  : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (_, i) {
                      final a = albums[i];
                      return Dismissible(
                        key: ValueKey(a.albumId),
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
                              .deleteLikedAlbum(a.albumId);
                        },
                        child: ListTile(
                          leading: ThumbnailWidget(
                            imageUrl: a.thumbnailUrl,
                            size: 48,
                            shape: ThumbnailShape.rounded,
                          ),
                          title: Text(a.name),
                          subtitle: Text(
                            a.year != null
                                ? '${a.artistName} · ${a.year}'
                                : a.artistName,
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => context.push('/album/${a.albumId}'),
                          onLongPress:
                              () => ContextMenuSheet.showForAlbum(
                                context,
                                albumId: a.albumId,
                                name: a.name,
                                artist: a.artistName,
                                artistId: a.artistId,
                                thumbnailUrl: a.thumbnailUrl,
                                year: a.year,
                              ),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _ShimmerSongList extends StatelessWidget {
  const _ShimmerSongList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
