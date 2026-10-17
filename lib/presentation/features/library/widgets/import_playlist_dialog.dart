import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/playlist_url_parser.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/playlist_import_job_provider.dart';
import '../../../providers/spotify_sync_cooldown_provider.dart';
import '../providers/library_provider.dart';
import 'import_match_review_sheet.dart';
import 'import_progress_body.dart';

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
  var _started = false;
  var _handlingReview = false;

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

    final parsed = PlaylistUrlParser.parse(input);
    if (parsed == null) {
      setState(() {
        _error =
            l10n?.invalidPlaylistUrlOrId ??
            'Invalid YouTube or Spotify playlist URL';
      });
      return;
    }

    final job = ref.read(playlistImportJobProvider);
    if (job.isActive || job.phase == PlaylistImportJobPhase.awaitingReview) {
      setState(() {
        _error =
            l10n?.importJobAlreadyRunning ?? 'An import is already in progress';
      });
      return;
    }

    setState(() {
      _error = null;
      _started = true;
    });

    final notifier = ref.read(playlistImportJobProvider.notifier);
    try {
      if (parsed.kind == PlaylistImportKind.spotify) {
        await notifier.startSpotifyImport(parsed.id);
      } else {
        await notifier.startYoutubeImport(input);
      }
    } on PlaylistAlreadyLinkedException catch (e) {
      if (!mounted) return;
      setState(() => _started = false);
      await _handleAlreadyLinked(e, l10n);
    }
  }

  Future<void> _handleAlreadyLinked(
    PlaylistAlreadyLinkedException e,
    AppLocalizations? l10n,
  ) async {
    final sync = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n?.importPlaylist ?? 'Import Playlist'),
            content: Text(
              l10n?.playlistAlreadyImported(e.name) ??
                  'Already imported as "${e.name}". Sync instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n?.syncInstead ?? 'Sync'),
              ),
            ],
          ),
    );
    if (sync != true || !mounted) return;

    final playlists = await ref.read(playlistsProvider.future);
    LocalPlaylistModel? existing;
    for (final p in playlists) {
      if (p.id == e.localPlaylistId) {
        existing = p;
        break;
      }
    }
    if (existing != null && isSpotifySyncCoolingDown(existing)) {
      setState(() {
        _error =
            l10n?.playlistSyncSpotifyCooldown ??
            'Spotify sync is limited to once every 12 hours';
      });
      return;
    }

    setState(() => _started = true);
    final notifier = ref.read(playlistImportJobProvider.notifier);
    if (e.source == PlaylistImportKind.spotify) {
      await notifier.startSpotifySync(e.localPlaylistId);
    } else {
      await notifier.startYoutubeSync(e.localPlaylistId);
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
        if (mounted) {
          setState(() => _started = false);
        }
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
    final busy =
        _started &&
        job.uiOwner == PlaylistImportUiOwner.dialog &&
        (job.isActive || job.phase == PlaylistImportJobPhase.awaitingReview);

    ref.listen<PlaylistImportJobState>(playlistImportJobProvider, (prev, next) {
      if (next.uiOwner != PlaylistImportUiOwner.dialog) return;

      if (next.phase == PlaylistImportJobPhase.awaitingReview &&
          next.needsUiAttention &&
          (prev?.phase != PlaylistImportJobPhase.awaitingReview)) {
        ref.read(playlistImportJobProvider.notifier).acknowledgeUiAttention();
        _runReview(next);
      }

      if (next.phase == PlaylistImportJobPhase.completed &&
          next.importResult != null) {
        final result = next.importResult!;
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) Navigator.pop(context, result);
      }

      if (next.phase == PlaylistImportJobPhase.completed &&
          next.syncResult != null) {
        final sync = next.syncResult!;
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) {
          Navigator.pop(
            context,
            PlaylistImportResult(
              localPlaylistId: sync.localPlaylistId,
              name: sync.name,
              source: PlaylistImportKind.spotify,
              importedCount: sync.added,
              skippedCount: sync.skipped,
            ),
          );
        }
      }

      if (next.phase == PlaylistImportJobPhase.failed) {
        final msg = next.errorMessage;
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) {
          setState(() {
            _started = false;
            _error = msg;
          });
        }
      }

      if (next.phase == PlaylistImportJobPhase.cancelled) {
        ref.read(playlistImportJobProvider.notifier).clearTerminal();
        if (mounted) setState(() => _started = false);
      }
    });

    final overlay =
        widget.isSheet
            ? _buildSheet(context, busy, job)
            : _buildDialog(context, busy, job);
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) _minimize();
      },
      child: overlay,
    );
  }

  Widget _buildDialog(
    BuildContext context,
    bool busy,
    PlaylistImportJobState job,
  ) {
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
      content: _buildBody(context, l10n, busy, job),
      actions:
          busy
              ? [
                TextButton(
                  onPressed:
                      () =>
                          ref.read(playlistImportJobProvider.notifier).cancel(),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: _minimize,
                  child: Text(l10n?.importJobMinimize ?? 'Run in background'),
                ),
              ]
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

  Widget _buildSheet(
    BuildContext context,
    bool busy,
    PlaylistImportJobState job,
  ) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;
    final imePadding =
        Theme.of(context).platform == TargetPlatform.android
            ? 0.0
            : bottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: imePadding),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, keyboardOpen ? 8 : 16),
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
                SizedBox(height: keyboardOpen ? 8 : 16),
                _buildBody(context, l10n, busy, job, compact: keyboardOpen),
                SizedBox(height: keyboardOpen ? 8 : 16),
                if (busy)
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
                          child: Text(
                            l10n?.importJobMinimize ?? 'Run in background',
                          ),
                        ),
                      ),
                    ],
                  )
                else
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations? l10n,
    bool busy,
    PlaylistImportJobState job, {
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (busy) {
      return ImportProgressBody(
        phase: _mapPhase(job.phase),
        current: job.current,
        total: job.total,
        trackLabel:
            job.phase == PlaylistImportJobPhase.awaitingReview
                ? null
                : job.trackLabel,
        showAiAssist:
            job.isSpotify && job.phase != PlaylistImportJobPhase.awaitingReview,
        aiModelReady: job.aiModelReady,
        compact: compact,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            l10n?.importPlaylistHint ??
                'Paste a YouTube Music or Spotify playlist link.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText:
                l10n?.youtubePlaylistUrl ?? 'YouTube or Spotify playlist URL',
            prefixIcon: const Icon(LucideIcons.link2),
            errorText: _error,
            errorMaxLines: compact ? 2 : 3,
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
