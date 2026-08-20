import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/playlist_card.dart';
import 'providers/explore_provider.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(chartsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.charts,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: chartsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadExplore,
              onRetry: () => ref.invalidate(chartsProvider),
            ),
        data: (charts) {
          final width = MediaQuery.of(context).size.width;
          final crossAxisCount =
              width < kCompactBreakpoint
                  ? 2
                  : width < kExpandedBreakpoint
                  ? 4
                  : 6;
          final cardWidth =
              (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(chartsProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _CountryPicker(charts: charts)),
                ..._playlistSection(
                  context,
                  title: l10n.chartVideos,
                  playlists: charts.videos,
                  crossAxisCount: crossAxisCount,
                  cardWidth: cardWidth,
                ),
                if (charts.daily != null && charts.daily!.isNotEmpty)
                  ..._playlistSection(
                    context,
                    title: l10n.chartDaily,
                    playlists: charts.daily!,
                    crossAxisCount: crossAxisCount,
                    cardWidth: cardWidth,
                  ),
                if (charts.weekly != null && charts.weekly!.isNotEmpty)
                  ..._playlistSection(
                    context,
                    title: l10n.chartWeekly,
                    playlists: charts.weekly!,
                    crossAxisCount: crossAxisCount,
                    cardWidth: cardWidth,
                  ),
                if (charts.genres != null && charts.genres!.isNotEmpty)
                  ..._playlistSection(
                    context,
                    title: l10n.chartGenres,
                    playlists: charts.genres!,
                    crossAxisCount: crossAxisCount,
                    cardWidth: cardWidth,
                  ),
                if (charts.languages != null && charts.languages!.isNotEmpty)
                  ..._playlistSection(
                    context,
                    title: l10n.chartLanguages,
                    playlists: charts.languages!,
                    crossAxisCount: crossAxisCount,
                    cardWidth: cardWidth,
                  ),
                if (charts.artists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.topArtists,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final artist = charts.artists[index];
                        return ArtistCard(
                          artistId: artist.browseId,
                          name: artist.title,
                          thumbnailUrl:
                              artist.thumbnails.isNotEmpty
                                  ? artist.thumbnails.last.url
                                  : null,
                          monthlyListeners: artist.subscribers,
                          cardWidth: cardWidth,
                          heroTag: 'chart_artist_${artist.browseId}',
                        );
                      }, childCount: charts.artists.length),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _playlistSection(
    BuildContext context, {
    required String title,
    required List<ChartPlaylist> playlists,
    required int crossAxisCount,
    required double cardWidth,
  }) {
    if (playlists.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final playlist = playlists[index];
            return PlaylistCard(
              playlistId: playlist.playlistId,
              name: playlist.title,
              thumbnailUrl:
                  playlist.thumbnails.isNotEmpty
                      ? playlist.thumbnails.last.url
                      : null,
              cardWidth: cardWidth,
              heroTag: 'chart_playlist_${playlist.playlistId}',
            );
          }, childCount: playlists.length),
        ),
      ),
    ];
  }
}

class _CountryPicker extends ConsumerWidget {
  final ChartsResult charts;

  const _CountryPicker({required this.charts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = charts.countries.options;
    if (options.isEmpty) return const SizedBox.shrink();

    final selected =
        ref.watch(chartsCountryOverrideProvider) ?? charts.countries.selected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options.contains(selected) ? selected : options.first,
            items: [
              for (final code in options)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: (value) {
              if (value == null) return;
              ref.read(chartsCountryOverrideProvider.notifier).update(value);
            },
          ),
        ),
      ),
    );
  }
}
