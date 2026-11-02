import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/android_tv_provider.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../tv/widgets/tv_focusable.dart';
import '../providers/wrapped_narrative_provider.dart';
import 'sonora_wrapped_view.dart';

/// Opens Wrapped. Cloud Ask preparing gate only when narrative is available.
///
/// On Android TV the same fullscreen route is used; the story view and
/// preparing gate expose D-pad focusable chrome (share stays hidden on TV).
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
    final isTv = ref.watch(isAndroidTvProvider);

    final skip =
        isTv
            ? TvFocusable(
              autofocus: true,
              onSelect: _openWrapped,
              debugLabel: 'wrapped:skip-prepare',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  l10n.wrappedPreparingSkip,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            : TextButton(
              onPressed: _openWrapped,
              child: Text(l10n.wrappedPreparingSkip),
            );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isTv ? 48 : 32),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: skip),
              const Spacer(),
              Icon(
                LucideIcons.sparkles,
                size: isTv ? 64 : 48,
                color: scheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.wrappedPreparingTitle,
                textAlign: TextAlign.center,
                style:
                    isTv
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.wrappedPreparingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: isTv ? 18 : null,
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
