// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/settings_provider.dart';
import '../providers/library_provider.dart';

class LibraryHeaderControls extends ConsumerStatefulWidget {
  final bool showViewSwitcher;

  const LibraryHeaderControls({super.key, this.showViewSwitcher = false});

  @override
  ConsumerState<LibraryHeaderControls> createState() =>
      _LibraryHeaderControlsState();
}

class _LibraryHeaderControlsState extends ConsumerState<LibraryHeaderControls> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(librarySearchQueryProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final activeTab = ref.watch(libraryActiveTabProvider);

    ref.listen<String>(librarySearchQueryProvider, (prev, next) {
      if (next != _searchController.text) {
        _searchController.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔍 Search Bar
          SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchLibraryHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon:
                    query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () {
                            ref
                                .read(librarySearchQueryProvider.notifier)
                                .update('');
                          },
                        )
                        : null,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              onChanged: (val) {
                ref.read(librarySearchQueryProvider.notifier).update(val);
              },
            ),
          ),
          const SizedBox(height: 8),
          // ⇵ Sorting and View Switcher Row
          SizedBox(
            height: 48,
            child: Row(
              children: [
                _buildSortButton(context),
                const Spacer(),
                if (widget.showViewSwitcher)
                  IconButton(
                    icon: Icon(
                      isGridView ? LucideIcons.list : LucideIcons.layoutGrid,
                    ),
                    tooltip:
                        isGridView
                            ? AppLocalizations.of(context)!.viewList
                            : AppLocalizations.of(context)!.viewGrid,
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setLibraryGridView(!isGridView);
                    },
                  ),
                if (activeTab == 4)
                  IconButton(
                    onPressed: () => _clearHistory(context),
                    icon: const Icon(LucideIcons.trash),
                    tooltip: AppLocalizations.of(context)!.clear,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearHistory),
            content: Text(AppLocalizations.of(context)!.clearHistoryConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.clear),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearHistory();
      ref.invalidate(libraryHistoryProvider);
    }
  }

  Widget _buildSortButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeSort = ref.watch(librarySortTypeProvider);
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;

    String label = '';
    switch (activeSort) {
      case LibrarySortType.recentlyAdded:
        label = l10n.recentlyAdded;
      case LibrarySortType.leastRecentlyAdded:
        label = l10n.leastRecentlyAdded;
      case LibrarySortType.alphabetical:
        label = l10n.alphabetical;
      case LibrarySortType.alphabeticalReverse:
        label = l10n.alphabeticalReverse;
    }

    if (isMobile) {
      return TextButton.icon(
        onPressed: () => _showSortBottomSheet(context),
        icon: const Icon(LucideIcons.arrowUpDown, size: 16),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return PopupMenuButton<LibrarySortType>(
        initialValue: activeSort,
        onSelected: (value) {
          ref.read(librarySortTypeProvider.notifier).update(value);
        },
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: LibrarySortType.recentlyAdded,
                child: Text(l10n.recentlyAdded),
              ),
              PopupMenuItem(
                value: LibrarySortType.leastRecentlyAdded,
                child: Text(l10n.leastRecentlyAdded),
              ),
              PopupMenuItem(
                value: LibrarySortType.alphabetical,
                child: Text(l10n.alphabetical),
              ),
              PopupMenuItem(
                value: LibrarySortType.alphabeticalReverse,
                child: Text(l10n.alphabeticalReverse),
              ),
            ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.arrowUpDown, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showSortBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeSort = ref.read(librarySortTypeProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.sortBy,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildSortOptionTile(
                context,
                LibrarySortType.recentlyAdded,
                l10n.recentlyAdded,
                activeSort,
              ),
              _buildSortOptionTile(
                context,
                LibrarySortType.leastRecentlyAdded,
                l10n.leastRecentlyAdded,
                activeSort,
              ),
              _buildSortOptionTile(
                context,
                LibrarySortType.alphabetical,
                l10n.alphabetical,
                activeSort,
              ),
              _buildSortOptionTile(
                context,
                LibrarySortType.alphabeticalReverse,
                l10n.alphabeticalReverse,
                activeSort,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOptionTile(
    BuildContext context,
    LibrarySortType value,
    String label,
    LibrarySortType activeSort,
  ) {
    final isSelected = value == activeSort;
    return ListTile(
      leading: Icon(
        isSelected ? LucideIcons.check : null,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      trailing: Radio<LibrarySortType>(
        value: value,
        groupValue: activeSort,
        onChanged: (newValue) {
          if (newValue != null) {
            ref.read(librarySortTypeProvider.notifier).update(newValue);
          }
          Navigator.pop(context);
        },
      ),
      onTap: () {
        ref.read(librarySortTypeProvider.notifier).update(value);
        Navigator.pop(context);
      },
    );
  }
}
