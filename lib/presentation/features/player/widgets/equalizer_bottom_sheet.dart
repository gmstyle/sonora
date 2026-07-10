import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/equalizer_provider.dart';

class EqualizerBottomSheet extends ConsumerWidget {
  const EqualizerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EqualizerBottomSheet(),
    );
  }

  String _getPresetName(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'flat':
        return l10n.presetFlat;
      case 'bass_boost':
        return l10n.presetBassBoost;
      case 'rock':
        return l10n.presetRock;
      case 'pop':
        return l10n.presetPop;
      case 'classical':
        return l10n.presetClassical;
      case 'vocal':
        return l10n.presetVocal;
      case 'custom':
        return l10n.presetCustom;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final eqState = ref.watch(equalizerNotifierProvider);
    final eqNotifier = ref.read(equalizerNotifierProvider.notifier);

    final bandFrequencies = ['100 Hz', '300 Hz', '1 kHz', '3 kHz', '10 kHz'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sliders,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.equalizer,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        eqState.enabled ? l10n.onLabel : l10n.offLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: eqState.enabled,
                        onChanged: (val) {
                          eqNotifier.setEnabled(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Presets Selection
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: eqState.enabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !eqState.enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presets',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Show custom chip only if custom is selected
                            if (eqState.preset == 'custom')
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(
                                    _getPresetName(context, 'custom'),
                                  ),
                                  selected: true,
                                  onSelected: (_) {},
                                ),
                              ),
                            ...kEqualizerPresets.keys.map((presetKey) {
                              final isSelected = eqState.preset == presetKey;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(
                                    _getPresetName(context, presetKey),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      eqNotifier.setPreset(presetKey);
                                    }
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Vertical Sliders
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: eqState.enabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !eqState.enabled,
                  child: SizedBox(
                    height: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final gain = eqState.gains[index];
                        final gainText =
                            gain > 0
                                ? '+${gain.round()} dB'
                                : '${gain.round()} dB';

                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                gainText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: theme.sliderTheme.copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                    ),
                                    child: Slider(
                                      value: gain,
                                      min: -12.0,
                                      max: 12.0,
                                      divisions: 24,
                                      onChanged: (val) {
                                        eqNotifier.setGain(index, val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bandFrequencies[index],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
