import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/library/widgets/import_match_review_sheet.dart';
import '../../features/library/widgets/import_progress_body.dart';
import '../../features/library/widgets/linked_playlist_actions.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/playlist_import_job_provider.dart';

/// Handles review / completion UI when the import job is owned by the shell
/// (dialog was minimized or dismissed).
class PlaylistImportJobHost extends ConsumerStatefulWidget {
  const PlaylistImportJobHost({super.key});

  @override
  ConsumerState<PlaylistImportJobHost> createState() =>
      _PlaylistImportJobHostState();
}

class _PlaylistImportJobHostState extends ConsumerState<PlaylistImportJobHost> {
  var _handling = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaylistImportJobState>(playlistImportJobProvider, (prev, next) {
      if (next.uiOwner != PlaylistImportUiOwner.host) return;
      if (!next.needsUiAttention) return;
      if (_handling) return;
      _handle(next);
    });
    return const SizedBox.shrink();
  }

  Future<void> _handle(PlaylistImportJobState job) async {
    _handling = true;
    final notifier = ref.read(playlistImportJobProvider.notifier);
    try {
      notifier.acknowledgeUiAttention();

      if (job.phase == PlaylistImportJobPhase.awaitingReview) {
        await _runReview(job);
        return;
      }

      if (job.phase == PlaylistImportJobPhase.matching ||
          job.phase == PlaylistImportJobPhase.saving) {
        // Expanded from banner while still matching — optional progress sheet.
        if (!job.minimized) {
          await _showProgressSheet();
        }
        return;
      }

      if (job.phase == PlaylistImportJobPhase.completed) {
        _reportSuccess(job);
        ref.invalidate(playlistsProvider);
        notifier.clearTerminal();
        return;
      }

      if (job.phase == PlaylistImportJobPhase.failed) {
        final l10n = AppLocalizations.of(context);
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              job.errorMessage ?? l10n?.playlistSyncError ?? 'Import failed',
            );
        notifier.clearTerminal();
      }
    } finally {
      _handling = false;
    }
  }

  Future<void> _runReview(PlaylistImportJobState job) async {
    final ambiguous =
        job.importPlan?.ambiguous ?? job.refreshPlan?.ambiguous ?? const [];
    if (ambiguous.isEmpty) {
      await ref.read(playlistImportJobProvider.notifier).submitReview(const {});
      return;
    }

    final choices = await ImportMatchReviewSheet.show(context, ambiguous);
    final notifier = ref.read(playlistImportJobProvider.notifier);
    if (choices == null) {
      await notifier.cancel();
      return;
    }
    await notifier.submitReview(choices);
  }

  Future<void> _showProgressSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final job = ref.watch(playlistImportJobProvider);
            final l10n = AppLocalizations.of(context);
            if (!job.isActive &&
                job.phase != PlaylistImportJobPhase.awaitingReview) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              });
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n?.importPlaylist ?? 'Import Playlist',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ImportProgressBody(
                    phase: _mapPhase(job.phase),
                    current: job.current,
                    total: job.total,
                    trackLabel: job.trackLabel,
                    showAiAssist: job.isSpotify,
                    aiModelReady: job.aiModelReady,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            ref
                                .read(playlistImportJobProvider.notifier)
                                .minimize();
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            l10n?.importJobMinimize ?? 'Run in background',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed:
                              () =>
                                  ref
                                      .read(playlistImportJobProvider.notifier)
                                      .cancel(),
                          child: Text(l10n?.cancel ?? 'Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    // If still active after sheet close without explicit minimize, keep host.
    final job = ref.read(playlistImportJobProvider);
    if (job.isActive || job.phase == PlaylistImportJobPhase.awaitingReview) {
      ref.read(playlistImportJobProvider.notifier).minimize();
    }
  }

  ImportProgressPhase _mapPhase(PlaylistImportJobPhase phase) {
    return switch (phase) {
      PlaylistImportJobPhase.matching => ImportProgressPhase.matching,
      PlaylistImportJobPhase.awaitingReview => ImportProgressPhase.reviewing,
      PlaylistImportJobPhase.saving => ImportProgressPhase.saving,
      _ => ImportProgressPhase.generic,
    };
  }

  void _reportSuccess(PlaylistImportJobState job) {
    final l10n = AppLocalizations.of(context);
    final feedback = ref.read(actionFeedbackProvider.notifier);
    final importResult = job.importResult;
    if (importResult != null) {
      final message =
          importResult.skippedCount > 0
              ? (l10n?.playlistImportedPartial(
                    importResult.importedCount,
                    importResult.totalCount,
                  ) ??
                  'Imported ${importResult.importedCount} of ${importResult.totalCount} tracks')
              : (l10n?.playlistImported ?? 'Playlist imported successfully');
      feedback.report(message);
      return;
    }
    final syncResult = job.syncResult;
    if (syncResult != null && l10n != null) {
      feedback.report(
        formatPlaylistSyncResult(
          l10n,
          syncResult,
          sourceKind:
              job.jobKind == PlaylistImportJobKind.spotifySync
                  ? 'spotify'
                  : 'youtube',
        ),
      );
    }
  }
}
