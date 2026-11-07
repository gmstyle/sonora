import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import 'layouts/library_mobile_layout.dart';
import 'layouts/library_tablet_layout.dart';
import 'layouts/library_wide_layout.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
