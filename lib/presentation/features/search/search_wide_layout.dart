import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/library_notifier.dart';
import '../../shared/widgets/facet_wide_scaffold.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/search_suggestion_tile.dart';
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

/// Recents and quick handoff to the dedicated Ask Hub.
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
            child: SearchOpenAskButton(),
          ),
        ),
        Expanded(
          child: SearchRecentSearches(onTapSearch: onTapSearch, inRail: true),
        ),
      ],
    );
  }
}

class SearchOpenAskButton extends ConsumerWidget {
  const SearchOpenAskButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      shape: const StadiumBorder(),
      avatar: Icon(
        LucideIcons.sparkles,
        size: 16,
        color: isOffline ? scheme.onSurfaceVariant : scheme.primary,
      ),
      label: Text(l10n.askOpenFromSearch),
      onPressed: isOffline
          ? null
          : () {
              final rawQuery = ref.read(searchQueryProvider).trim();
              final uri = rawQuery.isEmpty
                  ? Uri(path: '/ask')
                  : Uri(path: '/ask', queryParameters: {'prompt': rawQuery});
              context.go(uri.toString());
            },
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
