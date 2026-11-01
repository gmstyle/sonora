import 'package:dpad/dpad.dart';
import 'package:flutter/widgets.dart';

import '../tv_shell_focus.dart';

/// Bridges Left-edge D-pad presses to the TV nav rail across FocusScopes.
class TvLeftToSidebar extends StatelessWidget {
  final String memoryKey;
  final Widget child;

  const TvLeftToSidebar({
    super.key,
    required this.memoryKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DpadRegion(
      memoryKey: memoryKey,
      debugLabel: memoryKey,
      horizontalEdge: DpadEdgeBehavior.stop,
      verticalEdge: DpadEdgeBehavior.leave,
      onEdge: (direction) {
        if (direction == TraversalDirection.left) {
          TvShellFocus.requestSidebar(context);
        }
      },
      child: child,
    );
  }
}
