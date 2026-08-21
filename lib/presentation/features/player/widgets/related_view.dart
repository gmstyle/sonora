import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/video_card.dart';
import '../player_navigation.dart';

final songRelatedProvider = FutureProvider.family<List<RelatedSection>, String>(
  (ref, videoId) async {
    final repo = ref.watch(musicRepositoryProvider);
    final watch = await repo.getWatchPlaylist(videoId: videoId);
    final relatedId = watch.relatedBrowseId;
    if (relatedId == null || relatedId.isEmpty) return [];
    return repo.getSongRelated(relatedId);
  },
);

class RelatedView extends ConsumerWidget {
  final String videoId;

  const RelatedView({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(songRelatedProvider(videoId));
    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return relatedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => ErrorRetryWidget(
            message: l10n.failedToLoadRelated,
            onRetry: () => ref.invalidate(songRelatedProvider(videoId)),
          ),
      data: (sections) {
        if (sections.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 48, color: pc.labelMuted),
                const SizedBox(height: 16),
                Text(
                  l10n.noRelatedContent,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];
            return _RelatedSectionBlock(section: section);
          },
        );
      },
    );
  }
}

class _RelatedSectionBlock extends ConsumerWidget {
  final RelatedSection section;

  const _RelatedSectionBlock({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = section.title.isNotEmpty ? section.title : '';
    final contents = section.contents;
    if (contents.isEmpty) return const SizedBox.shrink();

    // Description-only shelf
    if (contents.length == 1 && contents.first is String) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              contents.first as String,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final hasSongs = contents.any((c) => c is SongDetailed);
    final hasCards = contents.any(
      (c) =>
          c is AlbumDetailed ||
          c is ArtistDetailed ||
          c is PlaylistDetailed ||
          c is VideoDetailed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        if (hasSongs)
          ...contents.whereType<SongDetailed>().map(
            (song) => SongTile(
              videoId: song.videoId,
              title: song.name,
              artist: song.artist.name,
              artistId: song.artist.artistId,
              albumId: song.album?.albumId,
              thumbnailUrl:
                  song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
              duration: song.duration,
              isExplicit: song.isExplicit,
              onTap:
                  () => ref
                      .read(playerStateProvider.notifier)
                      .playVideoId(song.videoId, isExplicit: song.isExplicit),
            ),
          ),
        if (hasCards)
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: contents.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = contents[index];
                return _buildCard(context, item);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, dynamic item) {
    const cardWidth = 140.0;
    if (item is AlbumDetailed) {
      final heroTag = 'related_album_${item.albumId}';
      return AlbumCard(
        albumId: item.albumId,
        name: item.name,
        artist: item.artist.name,
        artistId: item.artist.artistId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        year: item.year,
        cardWidth: cardWidth,
        heroTag: heroTag,
        onTap:
            () => closeFullPlayerAndNavigate(
              context,
              '/album/${item.albumId}?heroTag=${Uri.encodeComponent(heroTag)}',
            ),
      );
    }
    if (item is ArtistDetailed) {
      final heroTag = 'related_artist_${item.artistId}';
      return ArtistCard(
        artistId: item.artistId,
        name: item.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        cardWidth: 120,
        heroTag: heroTag,
        onTap:
            () => closeFullPlayerAndNavigate(
              context,
              '/artist/${item.artistId}?heroTag=${Uri.encodeComponent(heroTag)}',
            ),
      );
    }
    if (item is PlaylistDetailed) {
      final heroTag = 'related_playlist_${item.playlistId}';
      return PlaylistCard(
        playlistId: item.playlistId,
        name: item.name,
        artist: item.artist.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        cardWidth: cardWidth,
        heroTag: heroTag,
        onTap:
            () => closeFullPlayerAndNavigate(
              context,
              '/playlist/${item.playlistId}?heroTag=${Uri.encodeComponent(heroTag)}',
            ),
      );
    }
    if (item is VideoDetailed) {
      return VideoCard(
        videoId: item.videoId,
        title: item.name,
        artist: item.artist.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        artistId: item.artist.artistId,
        isExplicit: item.isExplicit,
      );
    }
    return const SizedBox.shrink();
  }
}
