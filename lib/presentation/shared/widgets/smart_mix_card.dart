import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../providers/smart_playlists_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'scale_button.dart';
import 'hover_play_button.dart';

enum SmartMixType { mostPlayed, recentlyPlayed, forgottenFavorites }

/// Shared Pulse brand fills for smart-mix tiles (home, library, detail).
LinearGradient smartMixGradient(SmartMixType type) {
  switch (type) {
    case SmartMixType.mostPlayed:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SonoraPulseTokens.gradientStart,
          SonoraPulseTokens.accentElectricBlue,
        ],
      );
    case SmartMixType.recentlyPlayed:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [SonoraPulseTokens.accentIndigo, SonoraPulseTokens.gradientEnd],
      );
    case SmartMixType.forgottenFavorites:
      return SonoraPulseTokens.brandSpectrum;
  }
}

class SmartMixCard extends ConsumerStatefulWidget {
  final SmartMixType type;
  final double cardWidth;

  const SmartMixCard({super.key, required this.type, this.cardWidth = 140});

  @override
  ConsumerState<SmartMixCard> createState() => _SmartMixCardState();
}

class _SmartMixCardState extends ConsumerState<SmartMixCard> {
  bool _isHovered = false;

  LinearGradient _getGradient() => smartMixGradient(widget.type);

  IconData _getIcon() {
    switch (widget.type) {
      case SmartMixType.mostPlayed:
        return LucideIcons.flame;
      case SmartMixType.recentlyPlayed:
        return LucideIcons.history;
      case SmartMixType.forgottenFavorites:
        return LucideIcons.heart;
    }
  }

  String _getTitle(AppLocalizations l10n) {
    switch (widget.type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayed;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayed;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavorites;
    }
  }

  String _getDescription(AppLocalizations l10n) {
    switch (widget.type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayedDesc;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayedDesc;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavoritesDesc;
    }
  }

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    final title = _getTitle(l10n!);
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.playingPlaylist(title));

    try {
      List<dynamic> songs = [];
      switch (widget.type) {
        case SmartMixType.mostPlayed:
          songs = ref.read(mostPlayedSongsProvider).value ?? [];
          break;
        case SmartMixType.recentlyPlayed:
          songs = ref.read(recentlyPlayedSongsProvider).value ?? [];
          break;
        case SmartMixType.forgottenFavorites:
          songs = ref.read(forgottenFavoritesProvider).value ?? [];
          break;
      }

      if (songs.isNotEmpty) {
        final player = ref.read(playerStateProvider.notifier);
        await player.playSmartMix(songs, startIndex: 0);
      } else {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.noSongsInMix, kind: FeedbackKind.error);
      }
    } catch (e) {
      debugPrint('Failed to play mix: $e');
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    final mixTitle = _getTitle(l10n);
    final mixDesc = _getDescription(l10n);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleButton(
        onTap: () => context.push('/smart-mix/${widget.type.name}'),
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _getGradient(),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Icon(
                          _getIcon(),
                          size: widget.cardWidth * 0.4,
                          color: SonoraPulseTokens.onBrandGraphic,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: HoverPlayButton(
                      isVisible: _isHovered,
                      onTap: _play,
                      size: 32.0,
                      iconSize: 16.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fixed caption block so a 3-up row stays top-aligned even when
              // one description wraps to two lines.
              SizedBox(
                height: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mixTitle,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        mixDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
