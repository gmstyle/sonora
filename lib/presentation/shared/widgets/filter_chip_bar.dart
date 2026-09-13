import 'package:flutter/material.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Axis direction;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.vertical) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          final scheme = Theme.of(context).colorScheme;
          return Material(
            color:
                selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  options[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return FilterChip(
            label: Text(options[index]),
            selected: index == selectedIndex,
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}
