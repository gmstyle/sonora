import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/grounded_llm_result.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_insights_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';

/// Opens curiosities in one tap.
///
/// Compact / portrait: modal bottom sheet. Tablet & wide landscape: layouts
/// show [PlayerInsightsCard] inline when [PlayerInsightsState.isOpen].
class PlayerInsightsOverlay {
  PlayerInsightsOverlay._();

  static bool _useSheet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Matches full_player MobilePlayerLayout selection.
    return size.width < kCompactBreakpoint || size.height >= size.width;
  }

  static Future<void> open(BuildContext context, WidgetRef ref) async {
    final current = ref.read(playerStateProvider).currentSong;
    if (current == null) return;
    final track = QueueTrack.fromMediaItem(current);
    if (track.isEpisode) return;

    ref.read(playerSubViewProvider.notifier).set(PlayerSubView.none);

    final locale = Localizations.localeOf(context).languageCode;
    // Fire generation; UI watches [playerInsightsProvider].
    final pending = ref
        .read(playerInsightsProvider.notifier)
        .openInsights(
          videoId: track.videoId,
          title: current.title,
          artist: current.artist ?? '',
          album: track.album ?? current.album,
          locale: locale,
        );

    if (!_useSheet(context)) {
      await pending;
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => const SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: PlayerInsightsCard(embeddedInSheet: true),
            ),
          ),
    );

    ref.read(playerInsightsProvider.notifier).dismiss();
  }
}

/// Curiosities body: disclaimer, bullets, source chips.
class PlayerInsightsCard extends ConsumerWidget {
  const PlayerInsightsCard({super.key, this.embeddedInSheet = false});

  final bool embeddedInSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(playerInsightsProvider);
    final current = ref.watch(playerStateProvider).currentSong;
    final track = current != null ? QueueTrack.fromMediaItem(current) : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, embeddedInSheet ? 8 : 12, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.playerAskCuriosities,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${current.title} · ${current.artist ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(playerInsightsProvider.notifier).dismiss();
                  if (embeddedInSheet) {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: const Icon(LucideIcons.x),
                tooltip: l10n.playerAskClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AiDisclaimer(),
          const SizedBox(height: 16),
          _body(context, ref, l10n, state, track, current),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PlayerInsightsState state,
    QueueTrack? track,
    MediaItem? current,
  ) {
    if (state.phase == PlayerInsightsPhase.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.phase == PlayerInsightsPhase.error) {
      VoidCallback? onRetry;
      if (current != null && track != null) {
        onRetry = () {
          final locale = Localizations.localeOf(context).languageCode;
          ref
              .read(playerInsightsProvider.notifier)
              .retry(
                videoId: track.videoId,
                title: current.title,
                artist: current.artist ?? '',
                album: track.album ?? current.album,
                locale: locale,
              );
        };
      }

      // Soft empty (no grounded facts) matches Related / lyrics-unavailable —
      // muted icon, not the red alert retry chrome.
      final softEmpty =
          state.errorKind == PlayerInsightsErrorKind.noSources ||
          state.errorKind == PlayerInsightsErrorKind.empty;
      if (softEmpty) {
        return _InsightsEmpty(
          message: _errorMessage(l10n, state.errorKind),
          onRetry: onRetry,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ErrorRetryWidget(
          message: _errorMessage(l10n, state.errorKind),
          onRetry: onRetry ?? () {},
        ),
      );
    }

    if (state.phase == PlayerInsightsPhase.ready && state.bullets.isNotEmpty) {
      return _InsightsResult(bullets: state.bullets, sources: state.sources);
    }

    return const SizedBox.shrink();
  }

  String _errorMessage(AppLocalizations l10n, PlayerInsightsErrorKind? kind) {
    return switch (kind) {
      PlayerInsightsErrorKind.unavailable => l10n.playerAskCloudRequired,
      PlayerInsightsErrorKind.noSources => l10n.playerAskNoSources,
      PlayerInsightsErrorKind.empty => l10n.playerAskEmpty,
      PlayerInsightsErrorKind.failed || null => l10n.playerAskFailed,
    };
  }
}

/// Soft “nothing useful found” — same language as Related empty / no lyrics.
class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sparkles, size: 48, color: pc.labelMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiDisclaimer extends StatelessWidget {
  const _AiDisclaimer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.sparkles, size: 18, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.playerAskAiDisclaimerTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.playerAskAiDisclaimerBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsResult extends StatelessWidget {
  const _InsightsResult({required this.bullets, required this.sources});

  final List<String> bullets;
  final List<GroundedSource> sources;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(
                        LucideIcons.circle,
                        size: 8,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(bullet)),
                  ],
                ),
              ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerAskSources,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in sources)
                    ActionChip(
                      avatar: const Icon(LucideIcons.externalLink, size: 14),
                      label: Text(source.displayTitle),
                      onPressed: () => _open(source.uri),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return;
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }
}
