import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/music_search_intent.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/moment_mix_provider.dart';
import '../../providers/on_device_llm_provider.dart';
import 'hover_play_button.dart';
import 'scale_button.dart';

/// Ask → Mix for this moment entry + result card.
///
/// Hidden when the Ask model is not installed. Shared by Home Your mixes and
/// Library Smart mixes.
class MomentMixAskSection extends ConsumerStatefulWidget {
  const MomentMixAskSection({
    super.key,
    this.horizontalPadding = 16,
    this.topPadding = 0,
  });

  final double horizontalPadding;
  final double topPadding;

  @override
  ConsumerState<MomentMixAskSection> createState() =>
      _MomentMixAskSectionState();
}

class _MomentMixAskSectionState extends ConsumerState<MomentMixAskSection> {
  final _controller = TextEditingController();
  bool _hovered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate(AppLocalizations l10n) async {
    final phrase = _controller.text.trim();
    if (phrase.isEmpty) return;

    final error = await ref.read(momentMixProvider.notifier).generate(phrase);
    if (!mounted) return;
    if (error != null) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report(_errorMessage(l10n, error), kind: FeedbackKind.error);
    }
  }

  Future<void> _play(AppLocalizations l10n) async {
    final mix = ref.read(momentMixProvider);
    final title = momentMixTitle(l10n, mix.intent);
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.playingPlaylist(title));

    final error = await ref.read(momentMixProvider.notifier).play();
    if (!mounted) return;
    if (error != null) {
      ref
          .read(actionFeedbackProvider.notifier)
          .report(_errorMessage(l10n, error), kind: FeedbackKind.error);
    }
  }

  String _errorMessage(AppLocalizations l10n, MomentMixErrorKind kind) {
    return switch (kind) {
      MomentMixErrorKind.modelUnavailable => l10n.askModelRequired,
      MomentMixErrorKind.interpretFailed => l10n.momentMixInterpretFailed,
      MomentMixErrorKind.emptyQueue => l10n.momentMixEmpty,
      MomentMixErrorKind.offlineNeedsYtm => l10n.momentMixOfflineYtm,
      MomentMixErrorKind.playFailed => l10n.failedToPlay,
    };
  }

  @override
  Widget build(BuildContext context) {
    final modelReadyAsync = ref.watch(askLlmReadyProvider);
    final modelReady = modelReadyAsync.asData?.value ?? false;
    if (!modelReady) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    final mix = ref.watch(momentMixProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final busy =
        mix.phase == MomentMixPhase.interpreting ||
        mix.phase == MomentMixPhase.assembling;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        widget.topPadding,
        widget.horizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mixForThisMoment,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.mixForThisMomentHint,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !busy,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _generate(l10n),
                  decoration: InputDecoration(
                    hintText: l10n.momentMixPromptHint,
                    filled: true,
                    fillColor: scheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : () => _generate(l10n),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    busy
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                        : const Icon(LucideIcons.sparkles, size: 20),
              ),
            ],
          ),
          if (isOffline) ...[
            const SizedBox(height: 8),
            Text(
              l10n.momentMixOfflineNote,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (mix.hasMix) ...[
            const SizedBox(height: 16),
            _MomentMixResultCard(
              title: momentMixTitle(l10n, mix.intent),
              subtitle: l10n.momentMixTrackCount(mix.tracks.length),
              hovered: _hovered,
              onHover: (v) => setState(() => _hovered = v),
              onOpen: () => context.push('/moment-mix'),
              onPlay: () => _play(l10n),
            ),
          ],
        ],
      ),
    );
  }
}

class _MomentMixResultCard extends StatelessWidget {
  const _MomentMixResultCard({
    required this.title,
    required this.subtitle,
    required this.hovered,
    required this.onHover,
    required this.onOpen,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF6A1B9A), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: ScaleButton(
        onTap: onOpen,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.sparkles,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: HoverPlayButton(
                      isVisible: hovered,
                      onTap: onPlay,
                      size: 28,
                      iconSize: 14,
                      iconColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlay,
              icon: const Icon(LucideIcons.play),
              tooltip: title,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card / save name: prefer LLM [MusicSearchIntent.title], else mood · energy l10n.
String momentMixTitle(AppLocalizations l10n, MusicSearchIntent? intent) {
  if (intent == null) return l10n.mixForThisMoment;

  final llmTitle = intent.title?.trim();
  if (llmTitle != null && llmTitle.isNotEmpty) return llmTitle;

  final moodLabel = switch (intent.mixMood) {
    MixMood.calm => l10n.mixMoodCalm,
    MixMood.energetic => l10n.mixMoodEnergetic,
    MixMood.focus => l10n.mixMoodFocus,
    MixMood.happy => l10n.mixMoodHappy,
    MixMood.melancholic => l10n.mixMoodMelancholic,
    MixMood.romantic => l10n.mixMoodRomantic,
    MixMood.workout => l10n.mixMoodWorkout,
    MixMood.party => l10n.mixMoodParty,
    MixMood.chill => l10n.mixMoodChill,
    MixMood.unknown => null,
  };

  final energyLabel = switch (intent.energy) {
    MixEnergy.low => l10n.mixEnergyLow,
    MixEnergy.medium => l10n.mixEnergyMedium,
    MixEnergy.high => l10n.mixEnergyHigh,
    MixEnergy.unknown => null,
  };

  final parts = <String>[
    if (moodLabel != null) moodLabel,
    if (energyLabel != null) energyLabel,
  ];
  if (parts.isEmpty) return l10n.mixForThisMoment;
  return parts.join(' · ');
}
