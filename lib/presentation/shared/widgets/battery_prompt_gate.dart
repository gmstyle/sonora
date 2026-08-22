import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/providers/home_provider.dart';
import '../../providers/battery_prompt_provider.dart';
import 'battery_optimization_prompt.dart';

/// Shows the battery-optimization prompt once per app session after the home
/// sections have finished loading, so it does not compete with the startup UI.
class BatteryPromptGate extends ConsumerStatefulWidget {
  const BatteryPromptGate({super.key});

  @override
  ConsumerState<BatteryPromptGate> createState() => _BatteryPromptGateState();
}

class _BatteryPromptGateState extends ConsumerState<BatteryPromptGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPrompt());
  }

  Future<void> _maybeShowPrompt() async {
    if (_checked || !mounted) return;
    _checked = true;

    // Wait until home data settles (success or error) before prompting.
    try {
      await ref.read(homeBaseSectionsProvider.future);
    } catch (_) {
      // Home failed to load — still proceed with the prompt.
    }
    if (!mounted) return;

    final shouldShow = await ref.read(shouldShowBatteryPromptProvider.future);
    if (!mounted || !shouldShow) return;

    await showBatteryOptimizationPrompt(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
