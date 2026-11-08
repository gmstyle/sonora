import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/feed_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/music_repository_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';

final artistSongsProvider = FutureProvider.family<List<SongDetailed>, String>((
  ref,
  artistId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getArtistSongs(artistId);
});

class ArtistSongsScreen extends ConsumerWidget {
  final String artistId;
  final String? artistName;

  const ArtistSongsScreen({super.key, required this.artistId, this.artistName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(artistSongsProvider(artistId));
    final l10n = AppLocalizations.of(context)!;
    final name = artistName;
    final title = name != null && name.isNotEmpty
        ? '${l10n.popular} · $name'
        : l10n.popular;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: songsAsync.when(
        loading: () => const _SongsLoadingList(),
        error: (e, _) => ErrorRetryWidget(
          message: l10n.failedToLoadSongs,
          onRetry: () => ref.invalidate(artistSongsProvider(artistId)),
        ),
        data: (songs) {
          if (songs.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.maxWidth;
              final isWide = viewport >= kExpandedBreakpoint;
              final contentWidth = isWide && viewport > kDocumentContentMaxWidth
                  ? kDocumentContentMaxWidth
                  : viewport;
              final horizontalPad = FeedGridSpec.fromWidth(
                contentWidth,
                shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
              ).horizontalPadding;

              final list = RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(artistSongsProvider(artistId).future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          12,
                          horizontalPad,
                          8,
                        ),
                        child: Text(
                          l10n.songCount(songs.length),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        MediaQuery.paddingOf(context).bottom +
                            (isWide ? 48 : 16),
                      ),
                      sliver: SliverList.separated(
                        itemCount: songs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return SongTile(
                            index: index + 1,
                            videoId: song.videoId,
                            title: song.name,
                            artist: displayArtists(song.artists),
                            artists: song.artists,
                            thumbnailUrl: song.thumbnails.isNotEmpty
                                ? song.thumbnails.last.url
                                : null,
                            duration: song.duration,
                            isVideo: song.type == 'VIDEO',
                            albumName: song.album?.name,
                            artistId: primaryArtistId(song.artists),
                            albumId: song.album?.albumId,
                            trailingActions: [
                              if (statFigure(song.playCount) case final plays?)
                                Text(
                                  plays,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                            ],
                            isExplicit: song.isExplicit,
                            isPlayable: song.isPlayable,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (!isWide) return list;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kDocumentContentMaxWidth,
                  ),
                  child: list,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SongsLoadingList extends StatelessWidget {
  const _SongsLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: 10,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
