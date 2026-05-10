import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'layouts/home_mobile_layout.dart';
import 'layouts/home_tablet_layout.dart';
import 'layouts/home_wide_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return const HomeMobileLayout();
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return const HomeTabletLayout();
        } else {
          return const HomeWideLayout();
        }
      },
    );
  }
}
