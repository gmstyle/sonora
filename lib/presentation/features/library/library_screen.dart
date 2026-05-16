import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'layouts/library_mobile_layout.dart';
import 'layouts/library_tablet_layout.dart';
import 'layouts/library_wide_layout.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return const LibraryMobileLayout();
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return const LibraryTabletLayout();
        } else {
          return const LibraryWideLayout();
        }
      },
    );
  }
}
