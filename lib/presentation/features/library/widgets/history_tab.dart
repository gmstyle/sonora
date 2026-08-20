import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_tile.dart';
import '../providers/library_provider.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sortedHistoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: l10n.failedToLoadHistory,
            onRetry: () => ref.invalidate(libraryHistoryProvider),
          ),
      data: (history) {
        if (history.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.history,
            title: l10n.noListeningHistory,
            body: l10n.noListeningHistoryHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(libraryHistoryProvider.future),
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: history.length,
            itemBuilder: (_, i) {
              final h = history[i];
              final isEpisode = h.contentType == 'episode';
              return SongTile(
                videoId: h.videoId,
                title: h.title,
                artist: isEpisode ? '${l10n.episode} · ${h.artist}' : h.artist,
                thumbnailUrl: h.thumbnailUrl,
                duration: h.duration,
                isVideo: h.isVideo,
                isExplicit: h.isExplicit,
                onTap:
                    isEpisode
                        ? () => context.push('/episode/${h.videoId}')
                        : null,
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
