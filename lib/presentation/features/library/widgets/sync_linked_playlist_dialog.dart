import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/refresh_linked_playlist_use_case_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await ref
          .read(refreshLinkedPlaylistUseCaseProvider)
          .execute(
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
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = _formatError(e, l10n));
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
        l10n?.syncingPlaylist ?? 'Syncing…',
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
            l10n?.syncingPlaylist ?? 'Syncing…',
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
