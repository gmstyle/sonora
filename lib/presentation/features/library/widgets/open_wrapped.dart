import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/stats_provider.dart';
import '../providers/wrapped_narrative_provider.dart';
import 'sonora_wrapped_view.dart';

/// Opens Wrapped. Cloud Ask preparing gate only when narrative is available.
Future<void> openSonoraWrapped(BuildContext context, WidgetRef ref) async {
  final stats = ref.read(statsProvider);
  if (stats.isLoading || !stats.isWrappedAvailable) return;
  ref.read(settingsProvider.notifier).markWrappedSeen();

  final locale = Localizations.localeOf(context).languageCode;
  final caps = await ref.read(askCapabilitiesProvider.future);
  if (!context.mounted) return;

  if (!caps.canWrappedNarrative) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SonoraWrappedView(stats: stats),
      ),
    );
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _WrappedPreparingGate(stats: stats, locale: locale),
    ),
  );
}

class _WrappedPreparingGate extends ConsumerStatefulWidget {
  const _WrappedPreparingGate({required this.stats, required this.locale});

  final StatsState stats;
  final String locale;

  @override
  ConsumerState<_WrappedPreparingGate> createState() =>
      _WrappedPreparingGateState();
}

class _WrappedPreparingGateState extends ConsumerState<_WrappedPreparingGate> {
  var _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    await ref
        .read(wrappedNarrativeProvider.notifier)
        .ensureGenerated(
          stats: widget.stats,
          locale: widget.locale,
          force: true,
        );
    if (!mounted || _opened) return;
    _openWrapped();
  }

  void _openWrapped() {
    if (_opened || !mounted) return;
    _opened = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SonoraWrappedView(stats: widget.stats),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final generating = ref.watch(wrappedNarrativeProvider).generating;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openWrapped,
                  child: Text(l10n.wrappedPreparingSkip),
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.sparkles, size: 48, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                l10n.wrappedPreparingTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.wrappedPreparingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              if (generating) const CircularProgressIndicator(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
