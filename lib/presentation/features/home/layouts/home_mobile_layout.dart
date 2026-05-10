import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/duration_ext.dart' show DurationFormat;
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/home_provider.dart';

class HomeMobileLayout extends ConsumerWidget {
  const HomeMobileLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sonora', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
      ),
      body: sectionsAsync.when(
        loading: () => _HomeShimmer(),
        error:
            (e, _) => ErrorRetryWidget(
              message: 'Failed to load home feed',
              onRetry: () => ref.invalidate(homeSectionsProvider),
            ),
        data:
            (sections) => RefreshIndicator(
              onRefresh: () => ref.refresh(homeSectionsProvider.future),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _ContinueListening(historyAsync),
                  for (var i = 0; i < sections.length; i++)
                    _HomeSectionCard(section: sections[i], isFirst: i == 0),
                ],
              ),
            ),
      ),
    );
  }
}

class _ContinueListening extends StatelessWidget {
  final AsyncValue historyAsync;

  const _ContinueListening(this.historyAsync);

  @override
  Widget build(BuildContext context) {
    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Continue Listening',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return _ContinueListeningItem(item: item);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _ContinueListeningItem extends ConsumerWidget {
  final dynamic item;

  const _ContinueListeningItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap:
          () =>
              ref.read(playerStateProvider.notifier).playVideoId(item.videoId),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: item.thumbnailUrl,
                  size: 100,
                  shape: ThumbnailShape.rounded,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionCard extends ConsumerWidget {
  final HomeSection section;
  final bool isFirst;

  const _HomeSectionCard({required this.section, this.isFirst = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.contents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 220,
          child:
              isFirst
                  ? _HeroCarousel(items: section.contents)
                  : _HorizontalScrollableRow(items: section.contents),
        ),
      ],
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  final List<dynamic> items;

  const _HeroCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: PageController(viewportFraction: 0.85),
      padEnds: false,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 16 : 8,
            right: index == items.length - 1 ? 16 : 8,
          ),
          child: _buildItem(context, item),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    if (item is AlbumDetailed) {
      return _HeroCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _HeroCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _HeroCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _HeroCard({
    required this.thumbnailUrl,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailWidget(imageUrl: thumbnailUrl, size: double.infinity),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
    );
  }
}

class _HorizontalScrollableRow extends StatelessWidget {
  final List<dynamic> items;

  const _HorizontalScrollableRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const PageScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItem(context, item);
      },
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    if (item is SongDetailed) {
      return _CompactSongCard(
        videoId: item.videoId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        artist: item.artist.name,
        duration: item.duration,
      );
    }
    if (item is AlbumDetailed) {
      return _CompactCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _CompactCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CompactSongCard extends ConsumerWidget {
  final String videoId;
  final String? thumbnailUrl;
  final String title;
  final String artist;
  final int? duration;

  const _CompactSongCard({
    required this.videoId,
    required this.thumbnailUrl,
    required this.title,
    required this.artist,
    this.duration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(playerStateProvider.notifier).playVideoId(videoId),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 150,
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 150,
                  shape: ThumbnailShape.rounded,
                ),
                if (duration != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Duration(seconds: duration!).toMinutesSeconds(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _CompactCard({
    required this.thumbnailUrl,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 150,
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 150,
              shape: ThumbnailShape.rounded,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
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

class _HomeShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerLoading(variant: ShimmerVariant.carousel),
        const SizedBox(height: 24),
        ShimmerLoading(variant: ShimmerVariant.tile),
        ShimmerLoading(variant: ShimmerVariant.tile),
        ShimmerLoading(variant: ShimmerVariant.tile),
      ],
    );
  }
}
