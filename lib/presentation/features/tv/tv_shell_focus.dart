import 'package:flutter/widgets.dart';

/// Lets content shelves request focus back onto the TV nav rail.
///
/// Branch [Navigator]s each create their own [FocusScope], so D-pad `leave`
/// from a poster cannot reach the sidebar (different scope). Shelves call
/// [focusSidebar] from [DpadRegion.onEdge] instead.
class TvShellFocus extends InheritedWidget {
  final VoidCallback focusSidebar;

  const TvShellFocus({
    super.key,
    required this.focusSidebar,
    required super.child,
  });

  static TvShellFocus? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvShellFocus>();
  }

  static void requestSidebar(BuildContext context) {
    maybeOf(context)?.focusSidebar();
  }

  @override
  bool updateShouldNotify(TvShellFocus oldWidget) =>
      focusSidebar != oldWidget.focusSidebar;
}
