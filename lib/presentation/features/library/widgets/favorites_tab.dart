import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/library_models.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_tile.dart';
import '../providers/library_provider.dart';

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sortedLikedSongsProvider);
    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadFavorites,
            onRetry: () => ref.invalidate(likedSongsProvider),
          ),
      data: (songs) {
        if (songs.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.heart,
            title: AppLocalizations.of(context)!.noFavoritesYet,
            body: AppLocalizations.of(context)!.noFavoritesHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedSongsProvider.future),
          child: ListView.builder(
            itemCount: songs.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _FavoritesHeader(
                  songCount: songs.length,
                  onPlayAll: () => _playAll(context, ref, songs),
                  onShuffle: () => _shufflePlay(context, ref, songs),
                );
              }
              final s = songs[i - 1];
              return SongTile(
                videoId: s.videoId,
                title: s.title,
                artist: s.artist,
                thumbnailUrl: s.thumbnailUrl,
                artistId: s.artistId,
                albumId: s.albumId,
                isVideo: false,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _playAll(
    BuildContext context,
    WidgetRef ref,
    List<LikedSongModel> songs,
  ) async {
    final repo = ref.read(musicRepositoryProvider);
    final player = ref.read(playerStateProvider.notifier);
    ref
        .read(actionFeedbackProvider.notifier)
        .report(
          'Playing ${songs.length} ${AppLocalizations.of(context)!.songs}…',
        );
    try {
      final items = await _buildItems(repo, songs);
      if (items.isNotEmpty) {
        await player.playNow(items, initialIndex: 0);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToLoadSongs('$e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    List<LikedSongModel> songs,
  ) async {
    final repo = ref.read(musicRepositoryProvider);
    final player = ref.read(playerStateProvider.notifier);
    ref
        .read(actionFeedbackProvider.notifier)
        .report(
          'Shuffling ${songs.length} ${AppLocalizations.of(context)!.songs}…',
        );
    try {
      final shuffled = List<LikedSongModel>.from(songs)..shuffle();
      final items = await _buildItems(repo, shuffled);
      if (items.isNotEmpty) {
        await player.playNow(items);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToLoadSongs('$e'),
            ),
          ),
        );
      }
    }
  }

  Future<List<MediaItem>> _buildItems(
    MusicRepository repo,
    List<LikedSongModel> songs,
  ) async {
    if (songs.isEmpty) return [];

    String? firstUrl;
    try {
      firstUrl = await repo.getStreamUrl(songs.first.videoId);
    } catch (_) {}

    return [
      for (int i = 0; i < songs.length; i++)
        _toMediaItem(songs[i], i == 0 ? firstUrl : null),
    ];
  }

  MediaItem _toMediaItem(LikedSongModel s, String? url) {
    final extras = <String, dynamic>{
      if (url != null) 'url': url,
      if (url == null) 'needsUrl': true,
      'videoId': s.videoId,
      'isVideo': false,
    };
    if (s.artistId != null) extras['artistId'] = s.artistId;
    if (s.albumId != null) extras['albumId'] = s.albumId;

    return MediaItem(
      id: s.videoId,
      title: s.title,
      artist: s.artist,
      artUri: s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
      extras: extras,
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────

class _FavoritesHeader extends StatelessWidget {
  final int songCount;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  const _FavoritesHeader({
    required this.songCount,
    required this.onPlayAll,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.favorites,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '$songCount ${l10n.songs}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (isMobile)
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FilledButton(
                    onPressed: onPlayAll,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(LucideIcons.play, size: 28),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed: onShuffle,
                  tooltip: l10n.shufflePlay,
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPlayAll,
                  icon: const Icon(LucideIcons.play),
                  label: Text(l10n.playAll),
                ),
                OutlinedButton.icon(
                  onPressed: onShuffle,
                  icon: const Icon(LucideIcons.shuffle),
                  label: Text(l10n.shufflePlay),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Shimmer ────────────────────────────────────────────────────────

class _ShimmerSongList extends StatelessWidget {
  const _ShimmerSongList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
