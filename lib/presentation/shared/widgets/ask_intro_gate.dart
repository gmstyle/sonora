import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/providers/home_provider.dart';
import '../../providers/ask_intro_provider.dart';
import 'ask_intro_wizard.dart';

/// Shows the Ask intro wizard once after home sections have finished loading.
class AskIntroGate extends ConsumerStatefulWidget {
  const AskIntroGate({super.key});

  @override
  ConsumerState<AskIntroGate> createState() => _AskIntroGateState();
}

class _AskIntroGateState extends ConsumerState<AskIntroGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_checked || !mounted) return;
    _checked = true;

    try {
      await ref.read(homeBaseSectionsProvider.future);
    } catch (_) {
      // Home failed — still offer the intro.
    }
    if (!mounted) return;

    final shouldShow = await ref.read(shouldShowAiIntroProvider.future);
    if (!mounted || !shouldShow) return;

    await showAskIntroWizard(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
