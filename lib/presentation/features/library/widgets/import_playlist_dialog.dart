import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/import_playlist_providers.dart';

/// Horizontal inset used on tablet/wide so the card stays centered.
const double kImportPlaylistDialogInset = 24;

/// Locked card width on tablet (600–1199dp).
const double kImportPlaylistDialogTabletWidth = 480;

/// Locked card width on wide (≥1200dp). Matches Material 3 dialog max.
const double kImportPlaylistDialogWideWidth = 560;

/// Compact (<600dp) uses a full-width sheet; larger shells use a fixed card
/// so pasting a long URL cannot grow the overlay.
double importPlaylistDialogWidth(double screenWidth) {
  if (screenWidth < kCompactBreakpoint) {
    return screenWidth;
  }
  final target =
      screenWidth < kExpandedBreakpoint
          ? kImportPlaylistDialogTabletWidth
          : kImportPlaylistDialogWideWidth;
  return math.min(target, screenWidth - (kImportPlaylistDialogInset * 2));
}

bool importPlaylistUsesSheet(double screenWidth) =>
    screenWidth < kCompactBreakpoint;

class ImportPlaylistDialog extends ConsumerStatefulWidget {
  const ImportPlaylistDialog({super.key, this.isSheet = false});

  final bool isSheet;

  static Future<PlaylistImportResult?> show(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (importPlaylistUsesSheet(width)) {
      return showModalBottomSheet<PlaylistImportResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const ImportPlaylistDialog(isSheet: true),
      );
    }
    return showDialog<PlaylistImportResult>(
      context: context,
      builder: (_) => const ImportPlaylistDialog(),
    );
  }

  @override
  ConsumerState<ImportPlaylistDialog> createState() =>
      _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends ConsumerState<ImportPlaylistDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;
  bool _isLoading = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations? l10n) async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error =
            l10n?.playlistUrlRequired ?? 'A playlist URL or ID is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _progressCurrent = 0;
      _progressTotal = 0;
    });

    try {
      final result = await ref
          .read(importRemotePlaylistUseCaseProvider)
          .execute(
            input,
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
        setState(() {
          _isLoading = false;
          final errStr = e.toString();
          if (e is ArgumentError) {
            _error =
                l10n?.invalidPlaylistUrlOrId ??
                'Invalid YouTube or Spotify playlist URL';
          } else if (errStr.contains('matched on YouTube Music')) {
            _error =
                l10n?.playlistNoMatchesError ??
                'No tracks from this Spotify playlist could be matched on YouTube Music';
          } else if (errStr.contains('empty') ||
              errStr.contains('could not be retrieved')) {
            _error =
                l10n?.playlistEmptyError ??
                'The playlist is empty or could not be retrieved';
          } else if (errStr.contains('SocketException') ||
              errStr.contains('Network') ||
              errStr.contains('HttpException') ||
              errStr.contains('Connection') ||
              errStr.contains('DioException')) {
            _error =
                l10n?.playlistSyncError ??
                'An error occurred while syncing. Please check your internet connection.';
          } else {
            _error = errStr.replaceAll('Exception: ', '');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay =
        widget.isSheet ? _buildSheet(context) : _buildDialog(context);
    return PopScope(canPop: !_isLoading, child: overlay);
  }

  Widget _buildDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dialogWidth = importPlaylistDialogWidth(
      MediaQuery.sizeOf(context).width,
    );

    return AlertDialog(
      scrollable: true,
      constraints: BoxConstraints(minWidth: dialogWidth, maxWidth: dialogWidth),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kImportPlaylistDialogInset,
        vertical: 24,
      ),
      title: Text(
        l10n?.importPlaylist ?? 'Import Playlist',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: _buildBody(context, l10n),
      actions:
          _isLoading
              ? null
              : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => _submit(l10n),
                  child: Text(l10n?.import ?? 'Import'),
                ),
              ],
    );
  }

  Widget _buildSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.importPlaylist ?? 'Import Playlist',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBody(context, l10n),
              if (!_isLoading) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n?.cancel ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _submit(l10n),
                        child: Text(l10n?.import ?? 'Import'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations? l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressLabel =
        _progressTotal > 0
            ? (l10n?.importingProgress(_progressCurrent, _progressTotal) ??
                'Importing $_progressCurrent/$_progressTotal…')
            : (l10n?.importing ?? 'Importing...');

    if (_isLoading) {
      return SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              progressLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.importPlaylistHint ??
              'Paste a YouTube Music or Spotify playlist link.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          enabled: !_isLoading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText:
                l10n?.youtubePlaylistUrl ?? 'YouTube or Spotify playlist URL',
            prefixIcon: const Icon(LucideIcons.link2),
            errorText: _error,
            errorMaxLines: 3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(l10n),
        ),
      ],
    );
  }
}
