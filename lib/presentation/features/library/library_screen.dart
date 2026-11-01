import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/android_tv_provider.dart';
import '../tv/screens/tv_library_screen.dart';
import 'layouts/library_mobile_layout.dart';
import 'layouts/library_tablet_layout.dart';
import 'layouts/library_wide_layout.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAndroidTvProvider)) {
      return const TvLibraryScreen();
    }
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
