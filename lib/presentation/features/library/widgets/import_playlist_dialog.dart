import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/import_playlist_providers.dart';

class ImportPlaylistDialog extends ConsumerStatefulWidget {
  const ImportPlaylistDialog({super.key});

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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final progressLabel =
        _progressTotal > 0
            ? (l10n?.importingProgress(_progressCurrent, _progressTotal) ??
                'Importing $_progressCurrent/$_progressTotal…')
            : (l10n?.importing ?? 'Importing...');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        l10n?.importPlaylist ?? 'Import Playlist',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content:
          _isLoading
              ? SizedBox(
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      progressLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
              : TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText:
                      l10n?.youtubePlaylistUrl ??
                      'YouTube or Spotify playlist URL',
                  errorText: _error,
                  errorMaxLines: 3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(l10n),
              ),
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
}
