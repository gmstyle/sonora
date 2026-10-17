import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/playlist_import_job_provider.dart';
import 'import_match_review_sheet.dart';
import 'import_playlist_dialog.dart';
import 'import_progress_body.dart';

/// Blocking sync progress UI — can minimize to the shared dock banner.
class SyncLinkedPlaylistDialog extends ConsumerStatefulWidget {
  const SyncLinkedPlaylistDialog({
    super.key,
    required this.playlist,
    this.isSheet = false,
  });

  final LocalPlaylistModel playlist;
  final bool isSheet;

  static Future<PlaylistSyncResult?> show(
    BuildContext context,
    LocalPlaylistModel playlist,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    if (importPlaylistUsesSheet(width)) {
      return showModalBottomSheet<PlaylistSyncResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder:
            (_) => SyncLinkedPlaylistDialog(playlist: playlist, isSheet: true),
      );
    }
    return showDialog<PlaylistSyncResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncLinkedPlaylistDialog(playlist: playlist),
    );
  }

  @override
  ConsumerState<SyncLinkedPlaylistDialog> createState() =>
      _SyncLinkedPlaylistDialogState();
}

class _SyncLinkedPlaylistDialogState
    extends ConsumerState<SyncLinkedPlaylistDialog> {
  var _handlingReview = false;
  String? _errorText;

  bool get _isSpotify => widget.playlist.sourceKind == 'spotify';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final notifier = ref.read(playlistImportJobProvider.notifier);
    final job = ref.read(playlistImportJobProvider);
    if (job.isActive || job.phase == PlaylistImportJobPhase.awaitingReview) {
      setState(() {
        _errorText =
            AppLocalizations.of(context)?.importJobAlreadyRunning ??
            'An import is already in progress';
      });
      return;
    }
    if (_isSpotify) {
      await notifier.startSpotifySync(widget.playlist.id);
    } else {
      await notifier.startYoutubeSync(widget.playlist.id);
    }
  }

  Future<void> _runReview(PlaylistImportJobState job) async {
    if (_handlingReview) return;
    _handlingReview = true;
    try {
      final ambiguous =
          job.importPlan?.ambiguous ?? job.refreshPlan?.ambiguous ?? const [];
      final choices = await ImportMatchReviewSheet.show(context, ambiguous);
      final notifier = ref.read(playlistImportJobProvider.notifier);
      if (choices == null) {
        await notifier.cancel();
        if (mounted) Navigator.pop(context);
        return;
      }
      await notifier.submitReview(choices);
    } finally {
      _handlingReview = false;
    }
  }

  void _minimize() {
    ref.read(playlistImportJobProvider.notifier).minimize();
    if (mounted) Navigator.pop(context);
  }

  ImportProgressPhase _mapPhase(PlaylistImportJobPhase phase) {
    return switch (phase) {
      PlaylistImportJobPhase.matching => ImportProgressPhase.matching,
      PlaylistImportJobPhase.awaitingReview => ImportProgressPhase.reviewing,
      PlaylistImportJobPhase.saving => ImportProgressPhase.saving,
      _ => ImportProgressPhase.generic,
    };
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(playlistImportJobProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen<PlaylistImportJobState>(playlistImportJobProvider, (prev, next) {
      if (next.uiOwner != PlaylistImportUiOwner.dialog) return;

      if (next.phase == PlaylistImportJobPhase.awaitingReview &&
          next.needsUiAttention &&
          prev?.phase != PlaylistImportJobPhase.awaitingReview) {
        ref.read(playlistImportJobProvider.notifier).acknowledgeUiAttention();
        _runReview(next);
      }

      if (next.phase == PlaylistImportJobPhase.completed &&
          next.syncResult != null) {
        final result = next.syncResult!;
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) Navigator.pop(context, result);
      }

      if (next.phase == PlaylistImportJobPhase.failed) {
        final msg = next.errorMessage;
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) setState(() => _errorText = msg);
      }

      if (next.phase == PlaylistImportJobPhase.cancelled) {
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) Navigator.pop(context);
      }
    });

    final busy =
        _errorText == null &&
        job.uiOwner == PlaylistImportUiOwner.dialog &&
        (job.isActive || job.phase == PlaylistImportJobPhase.awaitingReview);

    final overlay =
        widget.isSheet
            ? _buildSheet(context, l10n, busy, job)
            : _buildDialog(context, l10n, busy, job);
    return PopScope(
      canPop: _errorText != null || !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) _minimize();
      },
      child: overlay,
    );
  }

  Widget _buildDialog(
    BuildContext context,
    AppLocalizations? l10n,
    bool busy,
    PlaylistImportJobState job,
  ) {
    final dialogWidth = importPlaylistDialogWidth(
      MediaQuery.sizeOf(context).width,
    );
    return AlertDialog(
      constraints: BoxConstraints(minWidth: dialogWidth, maxWidth: dialogWidth),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kImportPlaylistDialogInset,
        vertical: 24,
      ),
      title: Text(
        l10n?.syncingPlaylist ?? 'Syncing…',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: _buildBody(context, l10n, busy, job),
      actions: [
        if (_errorText != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.cancel ?? 'Close'),
          )
        else if (busy) ...[
          TextButton(
            onPressed:
                () => ref.read(playlistImportJobProvider.notifier).cancel(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: _minimize,
            child: Text(l10n?.importJobMinimize ?? 'Run in background'),
          ),
        ],
      ],
    );
  }

  Widget _buildSheet(
    BuildContext context,
    AppLocalizations? l10n,
    bool busy,
    PlaylistImportJobState job,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: math.max(24, MediaQuery.paddingOf(context).bottom + 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.syncingPlaylist ?? 'Syncing…',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildBody(context, l10n, busy, job),
          const SizedBox(height: 16),
          if (_errorText != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n?.cancel ?? 'Close'),
              ),
            )
          else if (busy)
            Row(
              children: [
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
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _minimize,
                    child: Text(l10n?.importJobMinimize ?? 'Run in background'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations? l10n,
    bool busy,
    PlaylistImportJobState job,
  ) {
    if (_errorText != null) {
      return Text(
        _errorText!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return ImportProgressBody(
      phase: _mapPhase(job.phase),
      current: job.current,
      total: job.total,
      trackLabel:
          job.phase == PlaylistImportJobPhase.awaitingReview
              ? null
              : job.trackLabel,
      showAiAssist:
          _isSpotify && job.phase != PlaylistImportJobPhase.awaitingReview,
      aiModelReady: job.aiModelReady,
    );
  }
}
