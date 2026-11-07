import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/on_device_llm_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/facet_wide_scaffold.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/search_suggestion_tile.dart';
import 'providers/ask_search_provider.dart';
import 'providers/search_provider.dart';

List<String> searchFilterLabels(AppLocalizations l10n) {
  return [
    l10n.all,
    l10n.songs,
    l10n.searchArtists,
    l10n.searchAlbums,
    l10n.searchPlaylists,
    l10n.searchPodcasts,
    l10n.searchEpisodes,
    l10n.searchProfiles,
  ];
}

/// Wide Search frame: filter rail, padded results, utility rail at ≥1600.
class SearchWideFacet extends ConsumerWidget {
  final Widget child;
  final ValueChanged<String> onTapSearch;
  final bool showUtility;

  const SearchWideFacet({
    super.key,
    required this.child,
    required this.onTapSearch,
    required this.showUtility,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FacetWideScaffold(
      showUtility: showUtility,
      filterRail: const SearchFilterRail(),
      utilityRail: SearchUtilityRail(onTapSearch: onTapSearch),
      child: ListTileTheme.merge(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        child: child,
      ),
    );
  }
}

class SearchFilterRail extends ConsumerWidget {
  const SearchFilterRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final l10n = AppLocalizations.of(context)!;
    return FilterChipBar(
      direction: Axis.vertical,
      options: searchFilterLabels(l10n),
      selectedIndex: filter,
      onSelected: (index) =>
          ref.read(searchFilterProvider.notifier).update(index),
    );
  }
}

/// Recents, the Ask toggle, and the interpretation banner.
class SearchUtilityRail extends ConsumerWidget {
  final ValueChanged<String> onTapSearch;

  const SearchUtilityRail({super.key, required this.onTapSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SearchAskToggle(),
          ),
        ),
        const SearchAskBanner(padding: EdgeInsets.fromLTRB(12, 8, 8, 4)),
        Expanded(
          child: SearchRecentSearches(onTapSearch: onTapSearch, inRail: true),
        ),
      ],
    );
  }
}

class SearchAskToggle extends ConsumerWidget {
  const SearchAskToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);
    final askEnabled = ref.watch(askModeEnabledProvider);
    final modelReady = ref.watch(askLlmReadyProvider).asData?.value ?? false;
    final selected = askEnabled && modelReady;
    final scheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(l10n.askChip),
      selected: selected,
      avatar: Icon(
        LucideIcons.sparkles,
        size: 16,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onSelected: isOffline
          ? null
          : (value) {
              if (!modelReady) {
                ref
                    .read(actionFeedbackProvider.notifier)
                    .report(l10n.askModelRequired, kind: FeedbackKind.error);
                return;
              }
              ref.read(askModeEnabledProvider.notifier).setEnabled(value);
            },
    );
  }
}

class SearchAskBanner extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const SearchAskBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interpretation = ref.watch(askInterpretationProvider);
    if (interpretation == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(searchResultsProvider);
    final songs =
        resultsAsync.asData?.value.whereType<SongDetailed>().toList() ??
        const <SongDetailed>[];
    final canPlay = songs.isNotEmpty && !ref.watch(isOfflineProvider);

    return Padding(
      padding: padding,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.askInterpretedAs,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      interpretation.intent.displayLabel,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canPlay)
                IconButton.filled(
                  tooltip: l10n.askPlayResults,
                  onPressed: () =>
                      ref.read(playerStateProvider.notifier).playAlbum(songs),
                  icon: const Icon(LucideIcons.play, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-query prompt used when recents live in the utility rail.
class SearchIdlePrompt extends StatelessWidget {
  const SearchIdlePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.search,
                size: 64,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.searchForMusic,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.searchForMusicHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchRecentSearches extends ConsumerWidget {
  final ValueChanged<String> onTapSearch;

  /// Utility-rail list. Skips the large idle prompt.
  final bool inRail;

  /// Parent already applies the facet page padding.
  final bool inFacet;

  const SearchRecentSearches({
    super.key,
    required this.onTapSearch,
    this.inRail = false,
    this.inFacet = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) {
          if (inRail) return const SizedBox.shrink();
          return const SearchIdlePrompt();
        }

        final width = MediaQuery.sizeOf(context).width;
        final horizontal = inRail
            ? 16.0
            : inFacet
            ? 0.0
            : width >= kCompactBreakpoint
            ? kTabletContentPadding
            : 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                inRail ? 8 : 16,
                horizontal,
                8,
              ),
              child: Text(
                AppLocalizations.of(context)!.recentSearches,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final s = searches[index];
                  return SearchSuggestionTile(
                    query: s.query,
                    isHistory: true,
                    onTap: () => onTapSearch(s.query),
                    onDelete: () async {
                      await ref
                          .read(libraryNotifierProvider.notifier)
                          .deleteSearchEntry(s.query);
                      ref.invalidate(recentSearchesProvider);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
