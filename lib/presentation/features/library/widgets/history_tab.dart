import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
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

    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadHistory,
            onRetry: () => ref.invalidate(libraryHistoryProvider),
          ),
      data: (history) {
        if (history.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.history,
            title: AppLocalizations.of(context)!.noListeningHistory,
            body: AppLocalizations.of(context)!.noListeningHistoryHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(libraryHistoryProvider.future),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _clearHistory(context, ref),
                      icon: const Icon(LucideIcons.trash2),
                      label: Text(AppLocalizations.of(context)!.clear),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return SongTile(
                      videoId: h.videoId,
                      title: h.title,
                      artist: h.artist,
                      thumbnailUrl: h.thumbnailUrl,
                      isVideo: h.isVideo,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearHistory),
            content: Text(AppLocalizations.of(context)!.clearHistoryConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.clear),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearHistory();
      ref.invalidate(libraryHistoryProvider);
    }
  }
}

class _ShimmerSongList extends StatelessWidget {
  const _ShimmerSongList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}
