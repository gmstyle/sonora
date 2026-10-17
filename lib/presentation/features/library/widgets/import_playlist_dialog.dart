import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/playlist_url_parser.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../domain/usecases/playlist/import_spotify_playlist_use_case.dart';
import '../../../../domain/usecases/playlist/refresh_linked_playlist_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/import_playlist_providers.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/refresh_linked_playlist_use_case_provider.dart';
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
  bool _isLoading = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String? _trackLabel;
  bool _reviewing = false;
  bool _showAiAssist = false;
  bool _aiModelReady = false;
  ImportProgressPhase _phase = ImportProgressPhase.generic;

  void _applyProgress(PlaylistImportProgress progress) {
    if (!mounted) return;
    setState(() {
      _progressCurrent = progress.current;
      _progressTotal = progress.total;
      if (progress.trackLabel != null) {
        _trackLabel = progress.trackLabel;
      }
    });
  }

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

  Future<bool> _modelReady() async {
    try {
      return await ref.read(askModelReadyProvider.future);
    } catch (_) {
      return false;
    }
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

    setState(() {
      _isLoading = true;
      _error = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _trackLabel = null;
      _reviewing = false;
      _showAiAssist = parsed.kind == PlaylistImportKind.spotify;
      _phase =
          parsed.kind == PlaylistImportKind.spotify
              ? ImportProgressPhase.matching
              : ImportProgressPhase.generic;
    });
    if (parsed.kind == PlaylistImportKind.spotify) {
      _aiModelReady = await _modelReady();
      if (mounted) setState(() {});
    }

    try {
      if (parsed.kind == PlaylistImportKind.spotify) {
        final result = await _importSpotify(parsed.id, l10n);
        if (result != null && mounted) {
          Navigator.pop(context, result);
        }
        return;
      }

      final result = await ref
          .read(importRemotePlaylistUseCaseProvider)
          .execute(input);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } on PlaylistAlreadyLinkedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
      if (sync == true && mounted) {
        await _syncAlreadyLinked(e, l10n);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _reviewing = false;
          _error = _formatImportError(e, l10n);
        });
      }
    }
  }

  Future<PlaylistImportResult?> _importSpotify(
    String playlistId,
    AppLocalizations? l10n,
  ) async {
    final useCase = ref.read(importSpotifyPlaylistUseCaseProvider);
    final tryRewrite = _aiModelReady;
    final plan = await useCase.prepare(
      playlistId,
      tryRewrite: tryRewrite,
      onProgress: _applyProgress,
    );
    debugPrint(
      'Spotify import plan: auto=${plan.slots.where((s) => s.kind == SpotifyMatchKind.auto).length} '
      'review=${plan.ambiguous.length} none=${plan.noneCount} '
      'tryRewrite=$tryRewrite',
    );

    var resolved = plan;
    if (plan.ambiguous.isNotEmpty) {
      if (!mounted) return null;
      setState(() {
        _isLoading = false;
        _reviewing = true;
        _phase = ImportProgressPhase.reviewing;
        _trackLabel = null;
      });
      final choices = await ImportMatchReviewSheet.show(
        context,
        plan.ambiguous,
      );
      if (!mounted) return null;
      if (choices == null) {
        setState(() {
          _reviewing = false;
          _isLoading = false;
          _showAiAssist = false;
        });
        return null;
      }
      resolved = ImportSpotifyPlaylistUseCase.applyReviewChoices(plan, choices);
      setState(() {
        _reviewing = false;
        _isLoading = true;
        _phase = ImportProgressPhase.saving;
        _trackLabel = null;
      });
    } else if (mounted) {
      setState(() => _phase = ImportProgressPhase.saving);
    }

    try {
      return await useCase.commit(resolved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _formatImportError(e, l10n);
        });
      }
      return null;
    }
  }

  Future<void> _syncAlreadyLinked(
    PlaylistAlreadyLinkedException e,
    AppLocalizations? l10n,
  ) async {
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
    final isSpotify = e.source == PlaylistImportKind.spotify;
    setState(() {
      _isLoading = true;
      _progressCurrent = 0;
      _progressTotal = 0;
      _trackLabel = null;
      _reviewing = false;
      _showAiAssist = isSpotify;
      _phase =
          isSpotify
              ? ImportProgressPhase.matching
              : ImportProgressPhase.generic;
    });
    if (isSpotify) {
      _aiModelReady = await _modelReady();
      if (mounted) setState(() {});
    }
    try {
      final refresh = ref.read(refreshLinkedPlaylistUseCaseProvider);
      final tryRewrite = _aiModelReady;
      PlaylistSyncResult syncResult;
      if (isSpotify) {
        final plan = await refresh.prepareSpotify(
          e.localPlaylistId,
          tryRewrite: tryRewrite,
          onProgress: _applyProgress,
        );
        var resolved = plan;
        if (plan.ambiguous.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _reviewing = true;
            _phase = ImportProgressPhase.reviewing;
            _trackLabel = null;
          });
          final choices = await ImportMatchReviewSheet.show(
            context,
            plan.ambiguous,
          );
          if (!mounted) return;
          if (choices == null) {
            setState(() {
              _reviewing = false;
              _isLoading = false;
              _showAiAssist = false;
            });
            return;
          }
          resolved = RefreshLinkedPlaylistUseCase.applySpotifyReviewChoices(
            plan,
            choices,
          );
          setState(() {
            _reviewing = false;
            _isLoading = true;
            _phase = ImportProgressPhase.saving;
            _trackLabel = null;
          });
        } else if (mounted) {
          setState(() => _phase = ImportProgressPhase.saving);
        }
        syncResult = await refresh.commitSpotify(resolved);
      } else {
        syncResult = await refresh.execute(
          e.localPlaylistId,
          onProgress: _applyProgress,
        );
      }
      if (mounted) {
        Navigator.pop(
          context,
          PlaylistImportResult(
            localPlaylistId: syncResult.localPlaylistId,
            name: syncResult.name,
            source: e.source,
            importedCount: syncResult.added,
            skippedCount: syncResult.skipped,
          ),
        );
      }
    } catch (syncError) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _reviewing = false;
          _error = syncError.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  String _formatImportError(Object e, AppLocalizations? l10n) {
    final errStr = e.toString();
    if (e is ArgumentError) {
      return l10n?.invalidPlaylistUrlOrId ??
          'Invalid YouTube or Spotify playlist URL';
    }
    if (errStr.contains('matched on YouTube Music')) {
      return l10n?.playlistNoMatchesError ??
          'No tracks from this Spotify playlist could be matched on YouTube Music';
    }
    if (errStr.contains('empty') || errStr.contains('could not be retrieved')) {
      return l10n?.playlistEmptyError ??
          'The playlist is empty or could not be retrieved';
    }
    if (errStr.contains('SocketException') ||
        errStr.contains('Network') ||
        errStr.contains('HttpException') ||
        errStr.contains('Connection') ||
        errStr.contains('DioException')) {
      return l10n?.playlistSyncError ??
          'An error occurred while syncing. Please check your internet connection.';
    }
    debugPrint('Import playlist failed: $e');
    return errStr.replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final overlay =
        widget.isSheet ? _buildSheet(context) : _buildDialog(context);
    return PopScope(canPop: !_isLoading && !_reviewing, child: overlay);
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
          _isLoading || _reviewing
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
    final keyboardOpen = bottomInset > 0;
    // Android adjustResize already laid this sheet above the IME.
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
                _buildBody(context, l10n, compact: keyboardOpen),
                if (!_isLoading && !_reviewing) ...[
                  SizedBox(height: keyboardOpen ? 8 : 16),
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
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations? l10n, {
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading || _reviewing) {
      return ImportProgressBody(
        phase: _reviewing ? ImportProgressPhase.reviewing : _phase,
        current: _progressCurrent,
        total: _progressTotal,
        trackLabel: _reviewing ? null : _trackLabel,
        showAiAssist: _showAiAssist && !_reviewing,
        aiModelReady: _aiModelReady,
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
