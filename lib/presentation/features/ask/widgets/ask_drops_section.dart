import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/ask_chat_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/ask_storage_provider.dart';

/// Proactive discovery cards ("Pulse Drops") rendered either as a horizontal
/// strip on compact/tablet hubs or vertically in the wide utility rail.
class AskDropsSection extends ConsumerWidget {
  const AskDropsSection({
    super.key,
    required this.enabled,
    required this.onOpenDrop,
    this.vertical = false,
  });

  final bool enabled;
  final ValueChanged<AskProactiveDrop> onOpenDrop;
  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final drops = ref.watch(askActiveDropsProvider).asData?.value ?? const [];

    if (drops.isEmpty) {
      if (!vertical) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          color: cs.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.zap, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.askDropsEmpty,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(LucideIcons.zap, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.askDropsHeader,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          for (final drop in drops.take(4))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _DropCard(
                drop: drop,
                enabled: enabled,
                onTap: () => onOpenDrop(drop),
                onDismiss: () =>
                    ref.read(askStorageRepositoryProvider).dismissDrop(drop.id),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                l10n.askDropsHeader,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: drops.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final drop = drops[index];
              return SizedBox(
                width: 268,
                child: _DropCard(
                  drop: drop,
                  enabled: enabled,
                  onTap: () => onOpenDrop(drop),
                  onDismiss: () => ref
                      .read(askStorageRepositoryProvider)
                      .dismissDrop(drop.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DropCard extends StatelessWidget {
  const _DropCard({
    required this.drop,
    required this.enabled,
    required this.onTap,
    required this.onDismiss,
  });

  final AskProactiveDrop drop;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (!drop.isRead) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      drop.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                drop.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
