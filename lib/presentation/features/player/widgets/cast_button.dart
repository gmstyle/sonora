import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../providers/cast_provider.dart';
import 'cast_dialog.dart';

class CastButton extends ConsumerWidget {
  final Color? color;
  final double? size;

  const CastButton({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castStateAsync = ref.watch(castStateProvider);

    return castStateAsync.maybeWhen(
      data: (state) {
        final isConnected =
            state.connectionState == CastConnectionState.connected;
        final theme = Theme.of(context);

        return IconButton(
          icon: Icon(
            isConnected ? LucideIcons.cast : LucideIcons.cast,
            color: isConnected ? theme.colorScheme.primary : color,
            size: size,
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => const CastDialog(),
            );
          },
        );
      },
      orElse:
          () => IconButton(
            icon: Icon(LucideIcons.cast, color: color, size: size),
            onPressed: null,
          ),
    );
  }
}
