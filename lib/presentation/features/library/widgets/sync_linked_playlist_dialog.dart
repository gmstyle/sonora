import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../domain/usecases/playlist/refresh_linked_playlist_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/refresh_linked_playlist_use_case_provider.dart';
import 'import_match_review_sheet.dart';
import 'import_playlist_dialog.dart';

/// Blocking sync progress UI — identical for Spotify and YouTube.
///
/// Mirrors [ImportPlaylistDialog]'s loading body (spinner + current/total).
class SyncLinkedPlaylistDialog extends ConsumerStatefulWidget {
  const SyncLinkedPlaylistDialog({
    super.key,
    required this.playlist,
    this.isSheet = false,
  });

  final LocalPlaylistModel playlist;
  final bool isSheet;

  /// Shows a blocking overlay and runs [RefreshLinkedPlaylistUseCase].
  ///
  /// Returns the [PlaylistSyncResult] on success. Returns `null` if the user
  /// dismisses after an error (barrier is locked while loading).
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
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String? _errorText;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<bool> _modelReady() async {
    try {
      return await ref.read(askModelReadyProvider.future);
    } catch (_) {
      return false;
    }
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    try {
      final refresh = ref.read(refreshLinkedPlaylistUseCaseProvider);
      final PlaylistSyncResult result;

      if (widget.playlist.sourceKind == 'spotify') {
        final tryRewrite = await _modelReady();
        final plan = await refresh.prepareSpotify(
          widget.playlist.id,
          tryRewrite: tryRewrite,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _progressCurrent = current;
                _progressTotal = total;
              });
            }
          },
        );
        debugPrint(
          'Spotify sync plan: auto=${plan.slots.where((s) => s.kind == SpotifyMatchKind.auto).length} '
          'review=${plan.ambiguous.length} none=${plan.noneCount} '
          'tryRewrite=$tryRewrite',
        );

        var resolved = plan;
        if (plan.ambiguous.isNotEmpty) {
          if (!mounted) return;
          setState(() => _reviewing = true);
          final choices = await ImportMatchReviewSheet.show(
            context,
            plan.ambiguous,
          );
          if (!mounted) return;
          if (choices == null) {
            Navigator.pop(context);
            return;
          }
          resolved = RefreshLinkedPlaylistUseCase.applySpotifyReviewChoices(
            plan,
            choices,
          );
          setState(() => _reviewing = false);
        }
        result = await refresh.commitSpotify(resolved);
      } else {
        result = await refresh.execute(
          widget.playlist.id,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _progressCurrent = current;
                _progressTotal = total;
              });
            }
          },
        );
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewing = false;
          _errorText = _formatError(e, l10n);
        });
      }
    }
  }

  String _formatError(Object e, AppLocalizations? l10n) {
    if (e is SpotifyEmbedUnstableException) {
      return l10n?.playlistSyncSpotifyUnstable ?? e.toString();
    }
    final err = e.toString();
    if (err.contains('SocketException') ||
        err.contains('Network') ||
        err.contains('HttpException') ||
        err.contains('Connection') ||
        err.contains('DioException')) {
      return l10n?.playlistSyncError ??
          'An error occurred while syncing. Please check your internet connection.';
    }
    return err.replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overlay =
        widget.isSheet
            ? _buildSheet(context, l10n)
            : _buildDialog(context, l10n);
    return PopScope(canPop: _errorText != null, child: overlay);
  }

  Widget _buildDialog(BuildContext context, AppLocalizations? l10n) {
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
        _reviewing
            ? (l10n?.importMatchReviewTitle ?? 'Choose the right track')
            : (l10n?.syncingPlaylist ?? 'Syncing…'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: _buildBody(context, l10n),
      actions:
          _errorText != null
              ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n?.cancel ?? 'Close'),
                ),
              ]
              : null,
    );
  }

  Widget _buildSheet(BuildContext context, AppLocalizations? l10n) {
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
            _reviewing
                ? (l10n?.importMatchReviewTitle ?? 'Choose the right track')
                : (l10n?.syncingPlaylist ?? 'Syncing…'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildBody(context, l10n),
          if (_errorText != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n?.cancel ?? 'Close'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations? l10n) {
    if (_errorText != null) {
      return Text(
        _errorText!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (_reviewing) {
      return Text(
        l10n?.importMatchReviewing ?? 'Reviewing matches…',
        textAlign: TextAlign.center,
      );
    }
    final label =
        _progressTotal > 0
            ? (l10n?.importingProgress(_progressCurrent, _progressTotal) ??
                'Syncing $_progressCurrent/$_progressTotal…')
            : (l10n?.syncingPlaylist ?? 'Syncing…');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}
