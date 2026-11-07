import 'package:material_ui/material_ui.dart';

import 'layouts/home_feed_layout.dart';
import 'layouts/home_layout_metrics.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = HomeLayoutMetrics.fromWidth(
          constraints.maxWidth,
          shortestSide: MediaQuery.sizeOf(context).shortestSide,
        );
        return HomeFeedLayout(metrics: metrics);
      },
    );
  }
}
