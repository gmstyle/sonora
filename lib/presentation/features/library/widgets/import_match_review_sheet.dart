import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import 'import_playlist_dialog.dart';

/// Review overlay for ambiguous Spotify→YTM matches.
///
/// Returns a map of slot [SpotifyImportSlot.index] → chosen candidate
/// (`null` value means skip). Returns `null` if the user dismisses without
/// finishing.
class ImportMatchReviewSheet extends StatefulWidget {
  const ImportMatchReviewSheet({
    super.key,
    required this.ambiguous,
    this.isSheet = false,
  });

  final List<SpotifyImportSlot> ambiguous;
  final bool isSheet;

  static Future<Map<int, ImportedTrackCandidate?>?> show(
    BuildContext context,
    List<SpotifyImportSlot> ambiguous,
  ) {
    if (ambiguous.isEmpty) {
      return Future.value(<int, ImportedTrackCandidate?>{});
    }
    final width = MediaQuery.sizeOf(context).width;
    if (importPlaylistUsesSheet(width)) {
      return showModalBottomSheet<Map<int, ImportedTrackCandidate?>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder:
            (_) => ImportMatchReviewSheet(ambiguous: ambiguous, isSheet: true),
      );
    }
    return showDialog<Map<int, ImportedTrackCandidate?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportMatchReviewSheet(ambiguous: ambiguous),
    );
  }

  @override
  State<ImportMatchReviewSheet> createState() => _ImportMatchReviewSheetState();
}

class _ImportMatchReviewSheetState extends State<ImportMatchReviewSheet> {
  var _index = 0;
  String? _selectedVideoId;
  final _choices = <int, ImportedTrackCandidate?>{};

  SpotifyImportSlot get _current => widget.ambiguous[_index];

  @override
  void initState() {
    super.initState();
    _selectDefault();
  }

  void _selectDefault() {
    final candidates = _current.reviewCandidates;
    _selectedVideoId = candidates.isNotEmpty ? candidates.first.videoId : null;
  }

  void _confirm() {
    final selected =
        _current.reviewCandidates
            .where((c) => c.videoId == _selectedVideoId)
            .firstOrNull;
    _choices[_current.index] = selected;
    _advance();
  }

  void _skip() {
    _choices[_current.index] = null;
    _advance();
  }

  void _skipAllRemaining() {
    for (var i = _index; i < widget.ambiguous.length; i++) {
      _choices[widget.ambiguous[i].index] = null;
    }
    Navigator.pop(context, Map<int, ImportedTrackCandidate?>.from(_choices));
  }

  void _advance() {
    if (_index + 1 >= widget.ambiguous.length) {
      Navigator.pop(context, Map<int, ImportedTrackCandidate?>.from(_choices));
      return;
    }
    setState(() {
      _index++;
      _selectDefault();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overlay =
        widget.isSheet
            ? _buildSheet(context, l10n)
            : _buildDialog(context, l10n);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: overlay,
    );
  }

  Widget _buildDialog(BuildContext context, AppLocalizations? l10n) {
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
        l10n?.importMatchReviewTitle ?? 'Choose the right track',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: _buildBody(context, l10n),
      actions: _buildActions(context, l10n),
    );
  }

  Widget _buildSheet(BuildContext context, AppLocalizations? l10n) {
    final bottom = math.max(16.0, MediaQuery.paddingOf(context).bottom);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.importMatchReviewTitle ?? 'Choose the right track',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(child: _buildBody(context, l10n)),
          const SizedBox(height: 12),
          ..._buildSheetActions(context, l10n),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations? l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final track = _current.track;
    final artist = track.primaryArtist;
    final spotifyLabel =
        artist.isEmpty ? track.title : '${track.title} · $artist';
    final progress =
        l10n?.importMatchReviewProgress(_index + 1, widget.ambiguous.length) ??
        'Track ${_index + 1}/${widget.ambiguous.length}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          progress,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.importMatchReviewSpotifyLabel ?? 'From Spotify',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          spotifyLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: _selectedVideoId,
          onChanged: (v) => setState(() => _selectedVideoId = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in _current.reviewCandidates)
                _candidateTile(context, c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _candidateTile(BuildContext context, ImportedTrackCandidate c) {
    final selected = c.videoId == _selectedVideoId;
    final duration = _formatDuration(c.durationSec);
    final subtitle = duration == null ? c.artist : '${c.artist} · $duration';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: RadioListTile<String>(
          value: c.videoId,
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side:
                selected
                    ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    )
                    : BorderSide.none,
          ),
          secondary: ThumbnailWidget(
            imageUrl: c.thumbnailUrl,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, AppLocalizations? l10n) {
    return [
      TextButton(
        onPressed: _skipAllRemaining,
        child: Text(l10n?.importMatchSkipAll ?? 'Skip all remaining'),
      ),
      TextButton(
        onPressed: _skip,
        child: Text(l10n?.importMatchSkip ?? 'Skip'),
      ),
      FilledButton(
        onPressed: _selectedVideoId == null ? null : _confirm,
        child: Text(l10n?.confirm ?? 'Confirm'),
      ),
    ];
  }

  List<Widget> _buildSheetActions(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    return [
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _skip,
              child: Text(l10n?.importMatchSkip ?? 'Skip'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: _selectedVideoId == null ? null : _confirm,
              child: Text(l10n?.confirm ?? 'Confirm'),
            ),
          ),
        ],
      ),
      TextButton(
        onPressed: _skipAllRemaining,
        child: Text(l10n?.importMatchSkipAll ?? 'Skip all remaining'),
      ),
    ];
  }

  String? _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
