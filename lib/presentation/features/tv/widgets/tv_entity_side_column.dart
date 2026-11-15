import 'package:material_ui/material_ui.dart';

/// Left pane of the TV 40/60 entity split.
///
/// Art + stats + description + action stack can exceed the dock-constrained
/// height; this scrolls so focusable actions stay reachable via [TvFocusable]
/// `ensureVisible`.
class TvEntitySideColumn extends StatelessWidget {
  final List<Widget> children;
  final double width;

  const TvEntitySideColumn({
    super.key,
    required this.children,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}
