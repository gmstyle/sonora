import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/library_provider.dart';

class PodcastsTab extends ConsumerWidget {
  const PodcastsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sortedLikedPodcastsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;

    return async.when(
      loading: () => const _ShimmerPodcastList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.noLikedPodcasts,
            onRetry: () => ref.invalidate(likedPodcastsProvider),
          ),
      data: (podcasts) {
        if (podcasts.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.mic,
            title: AppLocalizations.of(context)!.noLikedPodcasts,
            body: AppLocalizations.of(context)!.noLikedPodcastsHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedPodcastsProvider.future),
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
                    itemCount: podcasts.length,
                    itemBuilder: (context, i) {
                      final p = podcasts[i];
                      return _PodcastGridTile(
                        browseId: p.browseId,
                        name: p.name,
                        authorName: p.authorName,
                        thumbnailUrl: p.thumbnailUrl,
                      );
                    },
                  )
                  : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    itemCount: podcasts.length,
                    itemBuilder: (_, i) {
                      final p = podcasts[i];
                      return Dismissible(
                        key: ValueKey(p.browseId),
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
                              .deleteLikedPodcast(p.browseId);
                        },
                        child: ListTile(
                          leading: ThumbnailWidget(
                            imageUrl: p.thumbnailUrl,
                            size: 48,
                            shape: ThumbnailShape.rounded,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            p.authorName ??
                                AppLocalizations.of(context)!.podcasts,
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => context.push('/podcast/${p.browseId}'),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _PodcastGridTile extends StatelessWidget {
  final String browseId;
  final String name;
  final String? authorName;
  final String? thumbnailUrl;

  const _PodcastGridTile({
    required this.browseId,
    required this.name,
    this.authorName,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/podcast/$browseId'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: double.infinity,
              shape: ThumbnailShape.rounded,
            ),
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
          if (authorName != null) ...[
            const SizedBox(height: 2),
            Text(
              authorName!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShimmerPodcastList extends StatelessWidget {
  const _ShimmerPodcastList();

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
