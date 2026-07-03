import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/smart_playlists_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'scale_button.dart';

enum SmartMixType { mostPlayed, recentlyPlayed, forgottenFavorites }

class SmartMixCard extends ConsumerStatefulWidget {
  final SmartMixType type;
  final double cardWidth;

  const SmartMixCard({super.key, required this.type, this.cardWidth = 140});

  @override
  ConsumerState<SmartMixCard> createState() => _SmartMixCardState();
}

class _SmartMixCardState extends ConsumerState<SmartMixCard> {
  bool _isHovered = false;

  LinearGradient _getGradient() {
    switch (widget.type) {
      case SmartMixType.mostPlayed:
        return const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.recentlyPlayed:
        return const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.forgottenFavorites:
        return const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

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
    ref.read(actionFeedbackProvider.notifier).report('Playing $title…');

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
            .report('No songs in this mix');
      }
    } catch (e) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report('Failed to play mix: $e');
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
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _getGradient(),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          _getIcon(),
                          size: widget.cardWidth * 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: ScaleButton(
                        onTap: _play,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.play,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mixTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                mixDesc,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
