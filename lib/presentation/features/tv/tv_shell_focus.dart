import 'package:material_ui/material_ui.dart';

/// Focus handoff between the TV content pane and the sidebar rail.
///
/// Scaffold only: call sites will request the sidebar when Left is pressed at
/// the leading edge of a shelf. No D-pad package yet.
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
