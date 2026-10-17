import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';

enum ImportProgressPhase { matching, reviewing, saving, generic }

/// Shared loading body for playlist import / sync overlays.
class ImportProgressBody extends StatelessWidget {
  const ImportProgressBody({
    super.key,
    required this.phase,
    required this.current,
    required this.total,
    this.trackLabel,
    this.showAiAssist = false,
    this.aiModelReady = false,
    this.compact = false,
  });

  final ImportProgressPhase phase;
  final int current;
  final int total;
  final String? trackLabel;

  /// Spotify path only — shows Ask assist / download invite.
  final bool showAiAssist;
  final bool aiModelReady;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final determinate = total > 0 && phase == ImportProgressPhase.matching;
    final progress = determinate ? (current / total).clamp(0.0, 1.0) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _phaseLabel(l10n),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (determinate)
              Text(
                '$current/$total',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        if (progress != null)
          LinearProgressIndicator(value: progress)
        else
          const LinearProgressIndicator(),
        if (trackLabel != null && trackLabel!.trim().isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 10),
          Text(
            trackLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showAiAssist) ...[
          SizedBox(height: compact ? 12 : 16),
          _AiAssistCard(modelReady: aiModelReady),
        ],
      ],
    );
  }

  String _phaseLabel(AppLocalizations? l10n) {
    switch (phase) {
      case ImportProgressPhase.matching:
        return l10n?.importProgressMatching ?? 'Matching on YouTube Music';
      case ImportProgressPhase.reviewing:
        return l10n?.importMatchReviewing ?? 'Reviewing matches…';
      case ImportProgressPhase.saving:
        return l10n?.importProgressSaving ?? 'Saving playlist…';
      case ImportProgressPhase.generic:
        return l10n?.importing ?? 'Importing...';
    }
  }
}

class _AiAssistCard extends StatelessWidget {
  const _AiAssistCard({required this.modelReady});

  final bool modelReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title =
        modelReady
            ? (l10n?.importAiAssistReadyTitle ?? 'AI assist available')
            : (l10n?.importAiAssistDisabledTitle ?? 'AI assist is off');
    final body =
        modelReady
            ? (l10n?.importAiAssistReadyBody ??
                'If a match is uncertain, Ask can rewrite the search — you confirm before anything is saved.')
            : (l10n?.importAiAssistDisabledBody ??
                'Download the Ask model in Settings → AI to improve uncertain Spotify matches.');

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.sparkles,
                  size: 20,
                  color:
                      modelReady
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!modelReady) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/settings'),
                  child: Text(
                    l10n?.importAiAssistOpenSettings ?? 'Open Settings',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
