import 'package:material_ui/material_ui.dart';

/// Focus handoff between TV content and the sidebar rail.
class TvShellFocus extends InheritedWidget {
  final VoidCallback focusSidebar;
  final VoidCallback focusContent;

  const TvShellFocus({
    super.key,
    required this.focusSidebar,
    required this.focusContent,
    required super.child,
  });

  static TvShellFocus? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvShellFocus>();
  }

  static void requestSidebar(BuildContext context) {
    maybeOf(context)?.focusSidebar();
  }

  static void requestContent(BuildContext context) {
    maybeOf(context)?.focusContent();
  }

  @override
  bool updateShouldNotify(TvShellFocus oldWidget) =>
      focusSidebar != oldWidget.focusSidebar ||
      focusContent != oldWidget.focusContent;
}
