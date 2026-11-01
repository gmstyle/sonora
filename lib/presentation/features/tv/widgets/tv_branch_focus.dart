import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/android_tv_provider.dart';

/// On Android TV, inactive [StatefulShellRoute.indexedStack] branches stay
/// mounted and would otherwise steal D-pad targets (e.g. Library's hidden
/// section rail sitting to the left of Home posters).
class TvBranchFocus extends ConsumerWidget {
  final int branchIndex;
  final Widget child;

  const TvBranchFocus({
    super.key,
    required this.branchIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAndroidTvProvider)) return child;

    final shell = StatefulNavigationShell.maybeOf(context);
    final current = shell?.widget.currentIndex ?? branchIndex;
    return ExcludeFocus(excluding: current != branchIndex, child: child);
  }
}
