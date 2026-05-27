import 'package:flutter/material.dart';
import 'horizontal_scroll_row.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: HorizontalScrollRow(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        builder: (context, controller) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          controller: controller,
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
      ),
    );
  }
}
