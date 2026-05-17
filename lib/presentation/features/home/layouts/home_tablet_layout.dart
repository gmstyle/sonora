import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_retry_widget.dart';
import '../providers/home_provider.dart';
import '../widgets/home_section_renderer.dart';

class HomeTabletLayout extends ConsumerWidget {
  const HomeTabletLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sonora', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
        actions: [
          if (Platform.isLinux)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(homeSectionsProvider);
                ref.invalidate(recentHistoryProvider);
              },
            ),
        ],
      ),
      body: sectionsAsync.when(
        loading: () => const HomeShimmer(tileCount: 4),
        error:
            (e, _) => ErrorRetryWidget(
              message: 'Failed to load home feed',
              onRetry: () => ref.invalidate(homeSectionsProvider),
            ),
        data:
            (sections) => RefreshIndicator(
              onRefresh: () => ref.refresh(homeSectionsProvider.future),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  HomeContinueListening(historyAsync),
                  for (var i = 0; i < sections.length; i++)
                    HomeSectionRow(
                      section: sections[i],
                      isFirst: i == 0,
                      cardWidth: 180,
                      heroViewportFraction: 0.7,
                      sectionPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
