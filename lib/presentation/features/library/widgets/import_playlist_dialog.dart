import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/sync_youtube_playlist_use_case_provider.dart';

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
    });

    try {
      await ref.read(syncYoutubePlaylistUseCaseProvider).execute(input);
      if (mounted) {
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final errStr = e.toString();
          if (e is ArgumentError) {
            _error =
                l10n?.invalidPlaylistUrlOrId ??
                'Invalid YouTube playlist URL or ID';
          } else if (errStr.contains('empty') ||
              errStr.contains('could not be retrieved')) {
            _error =
                l10n?.playlistEmptyError ??
                'The playlist is empty or could not be retrieved';
          } else if (errStr.contains('SocketException') ||
              errStr.contains('Network') ||
              errStr.contains('HttpException') ||
              errStr.contains('Connection')) {
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
                      l10n?.importing ?? 'Importing...',
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
                      l10n?.youtubePlaylistUrl ?? 'YouTube Playlist URL or ID',
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
