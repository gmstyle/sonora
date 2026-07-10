import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../providers/settings_provider.dart';

class SmartMixesTab extends ConsumerWidget {
  const SmartMixesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final gridDelegate =
        isMobile
            ? const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.64,
            )
            : const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170.0,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.64,
            );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.yourMixes,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (isGridView)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate((context, index) {
                final type = SmartMixType.values[index];
                return SmartMixCard(type: type, cardWidth: 150);
              }, childCount: 3),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding + 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final type = SmartMixType.values[index];
                return _SmartMixTile(type: type);
              }, childCount: 3),
            ),
          ),
      ],
    );
  }
}

class _SmartMixTile extends ConsumerWidget {
  final SmartMixType type;

  const _SmartMixTile({required this.type});

  LinearGradient _getGradient() {
    switch (type) {
      case SmartMixType.mostPlayed:
        return const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.recentlyPlayed:
        return const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.forgottenFavorites:
        return const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getIcon() {
    switch (type) {
      case SmartMixType.mostPlayed:
        return LucideIcons.flame;
      case SmartMixType.recentlyPlayed:
        return LucideIcons.history;
      case SmartMixType.forgottenFavorites:
        return LucideIcons.heart;
    }
  }

  String _getTitle(AppLocalizations l10n) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayed;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayed;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavorites;
    }
  }

  String _getDescription(AppLocalizations l10n) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayedDesc;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayedDesc;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavoritesDesc;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    final title = _getTitle(l10n);
    final desc = _getDescription(l10n);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: _getGradient(),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Icon(_getIcon(), size: 24, color: Colors.white)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(desc, overflow: TextOverflow.ellipsis, maxLines: 1),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => context.push('/smart-mix/${type.name}'),
    );
  }
}
