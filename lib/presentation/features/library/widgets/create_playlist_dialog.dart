import 'package:flutter/material.dart';

import 'package:sonora/l10n/app_localizations.dart';

class CreatePlaylistDialog extends StatefulWidget {
  final String? initialName;
  final String title;

  const CreatePlaylistDialog({
    super.key,
    this.initialName,
    this.title = 'New playlist',
  });

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _focusNode = FocusNode();
    if (widget.initialName != null) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n?.playlistName ?? 'Playlist name',
          hintText: l10n?.playlistName ?? 'My playlist',
          errorText: _error,
        ),
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(l10n),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n?.save ?? 'Save'),
        ),
      ],
    );
  }

  void _submit(AppLocalizations? l10n) {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(
        () =>
            _error =
                l10n?.playlistNameRequired ?? 'A playlist name is required',
      );
      return;
    }
    Navigator.pop(context, name);
  }
}
