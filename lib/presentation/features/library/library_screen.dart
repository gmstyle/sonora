import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
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
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return const LibraryMobileLayout();
        } else if (size.width < kExpandedBreakpoint) {
          return const LibraryTabletLayout();
        } else {
          return const LibraryWideLayout();
        }
      },
    );
  }
}
