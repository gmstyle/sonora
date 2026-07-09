import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/library_split_layout.dart';

class LibraryTabletLayout extends ConsumerWidget {
  const LibraryTabletLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const LibrarySplitLayout();
  }
}
