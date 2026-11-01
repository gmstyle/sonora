import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/android_tv_provider.dart';
import '../tv/screens/tv_home_screen.dart';
import 'layouts/home_feed_layout.dart';
import 'layouts/home_layout_metrics.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAndroidTvProvider)) {
      return const TvHomeScreen();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = HomeLayoutMetrics.fromWidth(constraints.maxWidth).size;
        return HomeFeedLayout(size: size);
      },
    );
  }
}
