import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_shimmer.dart';

Widget _tvTestHost(Widget child) {
  return MaterialApp(
    theme: TvTheme.apply(ThemeData.dark()),
    home: SizedBox(
      width: TvMetrics.designWidth,
      height: TvMetrics.designHeight,
      child: Scaffold(backgroundColor: TvColors.bg, body: child),
    ),
  );
}

void main() {
  testWidgets('TV shimmer skeletons render cleanly on 960x540 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(
      TvMetrics.designWidth,
      TvMetrics.designHeight,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_tvTestHost(const TvHomeShimmer()));
    await tester.pump();
    expect(find.byType(TvHomeShimmer), findsOneWidget);

    await tester.pumpWidget(
      _tvTestHost(const SingleChildScrollView(child: TvShelfShimmer(count: 2))),
    );
    await tester.pump();
    expect(find.byType(TvShelfShimmer), findsOneWidget);

    await tester.pumpWidget(_tvTestHost(const TvPosterGridShimmer()));
    await tester.pump();
    expect(find.byType(TvPosterGridShimmer), findsOneWidget);

    await tester.pumpWidget(_tvTestHost(const TvEntityShimmer()));
    await tester.pump();
    expect(find.byType(TvEntityShimmer), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
