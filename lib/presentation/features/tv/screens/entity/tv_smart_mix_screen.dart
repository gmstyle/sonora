import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/play_smart_mix_use_case_provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/smart_playlists_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/smart_mix_card.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_side_column.dart';
import '../../widgets/tv_entity_format.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_track_row.dart';

/// Standalone 10-foot Split 40/60 Smart Mix detail screen for Android TV.
class TvSmartMixScreen extends ConsumerStatefulWidget {
  final String type;

  const TvSmartMixScreen({super.key, required this.type});

  @override
  ConsumerState<TvSmartMixScreen> createState() => _TvSmartMixScreenState();
}

class _TvSmartMixScreenState extends ConsumerState<TvSmartMixScreen> {
  final FocusNode _playAllFocus = FocusNode(debugLabel: 'tvSmartMixPlayAll');

  @override
  void dispose() {
    _playAllFocus.dispose();
    super.dispose();
  }

  SmartMixType _resolveType() {
    return SmartMixType.values.firstWhere(
      (e) => e.name == widget.type,
      orElse: () => SmartMixType.mostPlayed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mixType = _resolveType();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playingVideoId = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.id),
    );

    final title = switch (mixType) {
      SmartMixType.mostPlayed => l10n.mostPlayed,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayed,
      SmartMixType.forgottenFavorites => l10n.forgottenFavorites,
    };
    final desc = switch (mixType) {
      SmartMixType.mostPlayed => l10n.mostPlayedDesc,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayedDesc,
      SmartMixType.forgottenFavorites => l10n.forgottenFavoritesDesc,
    };
    final icon = switch (mixType) {
      SmartMixType.mostPlayed => LucideIcons.flame,
      SmartMixType.recentlyPlayed => LucideIcons.history,
      SmartMixType.forgottenFavorites => LucideIcons.heart,
    };
    final gradient = smartMixGradient(context, mixType);

    final AsyncValue<List<dynamic>> songsAsync = switch (mixType) {
      SmartMixType.mostPlayed => ref.watch(mostPlayedSongsProvider),
      SmartMixType.recentlyPlayed => ref.watch(recentlyPlayedSongsProvider),
      SmartMixType.forgottenFavorites => ref.watch(forgottenFavoritesProvider),
    };

    return Scaffold(
      backgroundColor: TvColors.bg,
      body: songsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
        error: (e, _) => ErrorRetryWidget(
          message: l10n.failedToLoadSongs,
          onRetry: () {
            switch (mixType) {
              case SmartMixType.mostPlayed:
                ref.invalidate(mostPlayedSongsProvider);
              case SmartMixType.recentlyPlayed:
                ref.invalidate(recentlyPlayedSongsProvider);
              case SmartMixType.forgottenFavorites:
                ref.invalidate(forgottenFavoritesProvider);
            }
          },
        ),
        data: (songs) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TvMetrics.overscanHorizontal,
                TvMetrics.overscanVertical,
                TvMetrics.overscanHorizontal,
                TvMetrics.overscanVertical,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TvEntitySideColumn(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TvFocusable(
                          autofocus: songs.isEmpty,
                          onSelect: () => context.pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TvColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.chevronLeft,
                                  size: 16,
                                  color: TvColors.textPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.askIntroBack,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: TvColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 164,
                        height: 164,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(icon, size: 56, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: TvColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: TvColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.catalogSongCount(songs.length),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (songs.isNotEmpty)
                        SizedBox(
                          width: 224,
                          child: Column(
                            children: [
                              TvFocusable(
                                focusNode: _playAllFocus,
                                autofocus: true,
                                onSelect: () => ref
                                    .read(playerStateProvider.notifier)
                                    .playSmartMix(songs, startIndex: 0),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.play,
                                        size: 16,
                                        color: colorScheme.onPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.playAll,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TvFocusable(
                                onSelect: () {
                                  final shuffled = List<dynamic>.from(songs)
                                    ..shuffle();
                                  ref
                                      .read(playerStateProvider.notifier)
                                      .playSmartMix(shuffled, startIndex: 0);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: TvColors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        LucideIcons.shuffle,
                                        size: 15,
                                        color: TvColors.textPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.shufflePlay,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: TvColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TvFocusable(
                                onSelect: () => _addToQueue(context, songs),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        LucideIcons.listMusic,
                                        size: 15,
                                        color: TvColors.textPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.addToQueue,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: TvColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: songs.isEmpty
                        ? EmptyStateWidget(icon: icon, title: l10n.noSongsInMix)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      l10n.songs.toUpperCase(),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: TvColors.textSecondary,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      l10n.duration.toUpperCase(),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: TvColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: TvColors.border),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: songs.length,
                                  itemBuilder: (context, index) {
                                    final item = songs[index];
                                    final videoId = item is LikedSongModel
                                        ? item.videoId
                                        : (item as HistoryModel).videoId;
                                    final trackTitle = item is LikedSongModel
                                        ? item.title
                                        : (item as HistoryModel).title;
                                    final trackArtist = item is LikedSongModel
                                        ? item.artist
                                        : (item as HistoryModel).artist;
                                    final thumb = item is LikedSongModel
                                        ? item.thumbnailUrl
                                        : (item as HistoryModel).thumbnailUrl;
                                    final dur = item is LikedSongModel
                                        ? item.duration
                                        : (item as HistoryModel).duration;
                                    final isVid = item is LikedSongModel
                                        ? item.isVideo
                                        : (item as HistoryModel).isVideo;
                                    final isExp = item is LikedSongModel
                                        ? item.isExplicit
                                        : (item as HistoryModel).isExplicit;
                                    final playCountStr =
                                        mixType == SmartMixType.mostPlayed &&
                                            item is HistoryModel
                                        ? '${item.playCount}x'
                                        : null;

                                    return TvTrackRow(
                                      index: index,
                                      title: trackTitle,
                                      subtitle: trackArtist,
                                      duration: formatTrackDuration(dur),
                                      playCount: playCountStr,
                                      isExplicit: isExp,
                                      isPlaying: playingVideoId == videoId,
                                      onLeftAtEdge: () =>
                                          _playAllFocus.requestFocus(),
                                      onSelect: () => ref
                                          .read(playerStateProvider.notifier)
                                          .playSmartMix(
                                            songs,
                                            startIndex: index,
                                          ),
                                      onLongSelect: () =>
                                          ContextMenuSheet.showForSong(
                                            context,
                                            videoId: videoId,
                                            title: trackTitle,
                                            artist: trackArtist,
                                            thumbnailUrl: thumb,
                                            duration: dur,
                                            isVideo: isVid,
                                            isExplicit: isExp,
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addToQueue(BuildContext context, List<dynamic> songs) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await ref
          .read(playSmartMixUseCaseProvider)
          .execute(songs: songs, playIndex: -1);
      if (items.isNotEmpty) {
        await ref.read(playerStateProvider.notifier).addAllToQueue(items);
      }
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add smart mix to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
      }
    }
  }
}
