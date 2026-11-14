import 'package:material_ui/material_ui.dart';

/// Focus handoff between TV content, sidebar rail, and the mini-player dock.
class TvShellFocus extends InheritedWidget {
  final VoidCallback focusSidebar;
  final VoidCallback focusDock;
  final VoidCallback focusContent;

  const TvShellFocus({
    super.key,
    required this.focusSidebar,
    required this.focusDock,
    required this.focusContent,
    required super.child,
  });

  static TvShellFocus? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvShellFocus>();
  }

  static void requestSidebar(BuildContext context) {
    maybeOf(context)?.focusSidebar();
  }

  static void requestDock(BuildContext context) {
    maybeOf(context)?.focusDock();
  }

  static void requestContent(BuildContext context) {
    maybeOf(context)?.focusContent();
  }

  @override
  bool updateShouldNotify(TvShellFocus oldWidget) =>
      focusSidebar != oldWidget.focusSidebar ||
      focusDock != oldWidget.focusDock ||
      focusContent != oldWidget.focusContent;
}
