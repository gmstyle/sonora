import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../library/providers/library_provider.dart';

Future<String?> showAskExpandPlaylistSheet(BuildContext context) {
  return _showAskParametricOverlay(
    context,
    builder: (isDialog) => _ExpandPlaylistOverlayBody(isDialog: isDialog),
  );
}

Future<String?> showAskTailoredMixSheet(BuildContext context) {
  return _showAskParametricOverlay(
    context,
    builder: (isDialog) => _TailoredMixOverlayBody(isDialog: isDialog),
  );
}

Future<String?> _showAskParametricOverlay(
  BuildContext context, {
  required Widget Function(bool isDialog) builder,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;
  if (isWide) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: builder(true),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => builder(false),
  );
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.title, required this.isDialog});

  final String title;
  final bool isDialog;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (isDialog)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x),
          ),
      ],
    );
  }
}

enum _ExpandTarget { add15, reach30, reach50 }

class _ExpandPlaylistOverlayBody extends ConsumerStatefulWidget {
  const _ExpandPlaylistOverlayBody({required this.isDialog});

  final bool isDialog;

  @override
  ConsumerState<_ExpandPlaylistOverlayBody> createState() =>
      _ExpandPlaylistOverlayBodyState();
}

class _ExpandPlaylistOverlayBodyState
    extends ConsumerState<_ExpandPlaylistOverlayBody> {
  final TextEditingController _moodController = TextEditingController();
  int? _selectedPlaylistId;
  _ExpandTarget _target = _ExpandTarget.add15;

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final playlistsAsync = ref.watch(playlistsProvider);
    final bottomInset = widget.isDialog
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, widget.isDialog ? 20 : 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverlayHeader(
                title: l10n.askExpandSheetTitle,
                isDialog: widget.isDialog,
              ),
              const SizedBox(height: 16),
              playlistsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _EmptyPlaylistFallback(
                  message: l10n.askExpandNoPlaylists,
                  actionLabel: l10n.askGuidedPlaylistTitle,
                  onCreateNew: () =>
                      Navigator.of(context).pop(l10n.askGuidedPlaylistPrompt),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return _EmptyPlaylistFallback(
                      message: l10n.askExpandNoPlaylists,
                      actionLabel: l10n.askGuidedPlaylistTitle,
                      onCreateNew: () =>
                          Navigator.of(context)
                              .pop(l10n.askGuidedPlaylistPrompt),
                    );
                  }
                  final selected = _resolveSelected(playlists);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.askExpandPickPlaylist,
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final playlist in playlists)
                            ChoiceChip(
                              selected: playlist.id == selected.id,
                              avatar: Icon(
                                LucideIcons.listMusic,
                                size: 15,
                                color: playlist.id == selected.id
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                              label: Text(playlist.name),
                              onSelected: (_) => setState(
                                () => _selectedPlaylistId = playlist.id,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.askExpandTargetLabel,
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            selected: _target == _ExpandTarget.add15,
                            label: Text(l10n.askExpandTargetAdd15),
                            onSelected: (_) =>
                                setState(() => _target = _ExpandTarget.add15),
                          ),
                          ChoiceChip(
                            selected: _target == _ExpandTarget.reach30,
                            label: Text(l10n.askExpandTargetReach30),
                            onSelected: (_) =>
                                setState(() => _target = _ExpandTarget.reach30),
                          ),
                          ChoiceChip(
                            selected: _target == _ExpandTarget.reach50,
                            label: Text(l10n.askExpandTargetReach50),
                            onSelected: (_) =>
                                setState(() => _target = _ExpandTarget.reach50),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _moodController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.askExpandMoodLabel,
                          hintText: l10n.askExpandMoodHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _submit(context, l10n, selected),
                        icon: const Icon(LucideIcons.sparkles, size: 18),
                        label: Text(l10n.askExpandSubmit),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  LocalPlaylistModel _resolveSelected(List<LocalPlaylistModel> playlists) {
    for (final p in playlists) {
      if (p.id == _selectedPlaylistId) return p;
    }
    return playlists.first;
  }

  void _submit(
    BuildContext context,
    AppLocalizations l10n,
    LocalPlaylistModel playlist,
  ) {
    final base = switch (_target) {
      _ExpandTarget.add15 => l10n.askExpandPromptAdd(
        playlist.name,
        playlist.id,
        15,
      ),
      _ExpandTarget.reach30 => l10n.askExpandPromptReach(
        playlist.name,
        playlist.id,
        30,
      ),
      _ExpandTarget.reach50 => l10n.askExpandPromptReach(
        playlist.name,
        playlist.id,
        50,
      ),
    };
    final mood = _moodController.text.trim();
    final prompt = mood.isEmpty
        ? base
        : '$base${l10n.askExpandPromptMoodSuffix(mood)}';
    Navigator.of(context).pop(prompt);
  }
}

class _EmptyPlaylistFallback extends StatelessWidget {
  const _EmptyPlaylistFallback({
    required this.message,
    required this.actionLabel,
    required this.onCreateNew,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreateNew,
          icon: const Icon(LucideIcons.listPlus, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

enum _MixVibe { chill, focus, energetic, workout, surprise }

enum _MixSource { taste, nowPlaying, discovery }

class _TailoredMixOverlayBody extends StatefulWidget {
  const _TailoredMixOverlayBody({required this.isDialog});

  final bool isDialog;

  @override
  State<_TailoredMixOverlayBody> createState() =>
      _TailoredMixOverlayBodyState();
}

class _TailoredMixOverlayBodyState extends State<_TailoredMixOverlayBody> {
  _MixVibe _vibe = _MixVibe.chill;
  int _length = 15;
  _MixSource _source = _MixSource.taste;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, widget.isDialog ? 20 : 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverlayHeader(
              title: l10n.askMixSheetTitle,
              isDialog: widget.isDialog,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.askMixVibeLabel,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _MixVibe.values)
                  ChoiceChip(
                    selected: _vibe == v,
                    label: Text(_vibeLabel(v, l10n)),
                    onSelected: (_) => setState(() => _vibe = v),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.askMixLengthLabel,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in const [15, 30, 50])
                  ChoiceChip(
                    selected: _length == count,
                    label: Text(l10n.askTracksCount(count)),
                    onSelected: (_) => setState(() => _length = count),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.askMixSourceLabel,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final src in _MixSource.values)
                  ChoiceChip(
                    selected: _source == src,
                    label: Text(_sourceLabel(src, l10n)),
                    onSelected: (_) => setState(() => _source = src),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                final prompt = l10n.askTailoredMixPrompt(
                  _length,
                  _vibeLabel(_vibe, l10n),
                  _sourceLabel(_source, l10n),
                );
                Navigator.of(context).pop(prompt);
              },
              icon: const Icon(LucideIcons.listMusic, size: 18),
              label: Text(l10n.askMixSubmit),
            ),
          ],
        ),
      ),
    );
  }

  String _vibeLabel(_MixVibe vibe, AppLocalizations l10n) => switch (vibe) {
    _MixVibe.chill => l10n.askMixVibeChill,
    _MixVibe.focus => l10n.askMixVibeFocus,
    _MixVibe.energetic => l10n.askMixVibeEnergetic,
    _MixVibe.workout => l10n.askMixVibeWorkout,
    _MixVibe.surprise => l10n.askMixVibeSurprise,
  };

  String _sourceLabel(_MixSource src, AppLocalizations l10n) => switch (src) {
    _MixSource.taste => l10n.askMixSourceTaste,
    _MixSource.nowPlaying => l10n.askMixSourceNowPlaying,
    _MixSource.discovery => l10n.askMixSourceDiscovery,
  };
}
