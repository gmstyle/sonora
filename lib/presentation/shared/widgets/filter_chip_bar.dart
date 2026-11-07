import 'package:material_ui/material_ui.dart';

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
          return Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text(options[index]),
              selected: index == selectedIndex,
              onSelected: (_) => onSelected(index),
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
