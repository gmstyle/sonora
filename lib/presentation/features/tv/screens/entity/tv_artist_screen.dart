import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/utils/artists_utils.dart';
import '../../../../../core/utils/playable_tracks.dart';
import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/start_radio_use_case_provider.dart';
import '../../../../shared/widgets/context_menu/context_menu_presenter.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../artist/providers/artist_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_track_row.dart';

class TvArtistScreen extends ConsumerWidget {
  final String artistId;

  const TvArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistProvider(artistId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
      ),
      data: (artist) => _TvArtistBody(artist: artist),
    );
  }
}

class _TvArtistBody extends ConsumerWidget {
  final ArtistFull artist;

  const _TvArtistBody({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final offline = ref.watch(isOfflineProvider);
    final followed = ref
        .watch(followedArtistProvider(artist.artistId))
        .asData
        ?.value;
    final playable = playableSongs(artist.topSongs);
    final art = artist.thumbnails.isNotEmpty
        ? artist.thumbnails.last.url
        : null;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 420,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const reserved = 220.0;
                final artSize = (constraints.maxHeight - reserved)
                    .clamp(120.0, 280.0)
                    .clamp(
                      120.0,
                      constraints.maxWidth - TvMetrics.contentPadding * 2,
                    )
                    .toDouble();
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(TvMetrics.contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TvFocusable(
                        onSelect: () => context.pop(),
                        child: const Icon(LucideIcons.arrowLeft, size: 28),
                      ),
                      const SizedBox(height: 24),
                      ThumbnailWidget(
                        imageUrl: art,
                        size: artSize,
                        shape: ThumbnailShape.circle,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        artist.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TvFocusable(
                            autofocus: true,
                            onSelect: playable.isEmpty
                                ? null
                                : () => ref
                                      .read(playerStateProvider.notifier)
                                      .playAlbum(playable, startIndex: 0),
                            borderRadius: BorderRadius.circular(28),
                            child: FilledButton.icon(
                              onPressed: playable.isEmpty
                                  ? null
                                  : () => ref
                                        .read(playerStateProvider.notifier)
                                        .playAlbum(playable, startIndex: 0),
                              icon: const Icon(LucideIcons.play),
                              label: Text(l10n.playTopSongs),
                            ),
                          ),
                          TvFocusable(
                            onSelect: offline || playable.isEmpty
                                ? null
                                : () =>
                                      _startRadio(context, ref, playable.first),
                            borderRadius: BorderRadius.circular(28),
                            child: FilledButton.tonalIcon(
                              onPressed: offline || playable.isEmpty
                                  ? null
                                  : () => _startRadio(
                                      context,
                                      ref,
                                      playable.first,
                                    ),
                              icon: const Icon(LucideIcons.radio),
                              label: Text(l10n.startRadio),
                            ),
                          ),
                          TvFocusable(
                            onSelect: () {
                              ref
                                  .read(libraryNotifierProvider.notifier)
                                  .toggleFollowedArtist(
                                    FollowedArtistModel(
                                      artistId: artist.artistId,
                                      name: artist.name,
                                      thumbnailUrl: art,
                                      addedAt: DateTime.now(),
                                    ),
                                  );
                            },
                            child: Icon(
                              followed != null
                                  ? LucideIcons.userCheck
                                  : LucideIcons.userPlus,
                              color: followed != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 48, 48, 48),
              itemCount: artist.topSongs.length,
              itemBuilder: (context, index) {
                final song = artist.topSongs[index];
                return TvTrackRow(
                  index: index,
                  title: song.name,
                  subtitle: displayArtists(song.artists),
                  enabled: song.isPlayable,
                  onSelect: () {
                    final start = playable.indexWhere(
                      (s) => s.videoId == song.videoId,
                    );
                    if (start < 0) return;
                    ref
                        .read(playerStateProvider.notifier)
                        .playAlbum(playable, startIndex: start);
                  },
                  onLongSelect: () => ContextMenuSheet.showForSong(
                    context,
                    videoId: song.videoId,
                    title: song.name,
                    artist: displayArtists(song.artists),
                    artists: song.artists,
                    thumbnailUrl: song.thumbnails.isNotEmpty
                        ? song.thumbnails.last.url
                        : null,
                    isVideo: song.type == 'VIDEO',
                    isExplicit: song.isExplicit,
                    isPlayable: song.isPlayable,
                    artistId: artist.artistId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRadio(
    BuildContext context,
    WidgetRef ref,
    SongDetailed seed,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final radioId = artist.radioId;
    if (radioId != null && radioId.isNotEmpty) {
      try {
        final useCase = ref.read(startRadioUseCaseProvider);
        final result = await useCase.execute(seed.videoId, playlistId: radioId);
        final player = ref.read(playerStateProvider.notifier);
        await player.playNow([result.firstItem]);
        if (result.remaining.isNotEmpty) {
          player.addAllToQueue(useCase.toPendingItems(result.remaining));
        }
        return;
      } catch (e) {
        debugPrint('Artist radio failed: $e');
      }
    }
    await startSongRadio(
      videoId: seed.videoId,
      useCase: ref.read(startRadioUseCaseProvider),
      player: ref.read(playerStateProvider.notifier),
      feedback: ref.read(actionFeedbackProvider.notifier),
      l10n: l10n,
    );
  }
}
