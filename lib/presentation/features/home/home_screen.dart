import 'package:flutter/material.dart';

import 'layouts/home_feed_layout.dart';
import 'layouts/home_layout_metrics.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = HomeLayoutMetrics.fromWidth(constraints.maxWidth).size;
        return HomeFeedLayout(size: size);
      },
    );
  }
}
