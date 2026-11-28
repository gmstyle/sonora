import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/presentation/shared/widgets/detail_actions_bar.dart';
import 'package:sonora/presentation/shared/widgets/detail_affinity_button.dart';
import 'package:sonora/presentation/shared/widgets/entity_banner_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  DetailActionsBar buildBar() {
    return DetailActionsBar(
      onPlay: () {},
      playLabel: 'Riproduci brani popolari',
      onShuffle: () {},
      shuffleLabel: 'Casuale',
      alwaysShowOverflow: true,
      onOverflow: () {},
      secondary: [
        DetailAction(
          id: DetailActionId.queue,
          icon: LucideIcons.listMusic,
          label: 'In coda',
          tooltip: 'In coda',
          onPressed: () {},
        ),
        DetailAction(
          id: DetailActionId.save,
          icon: DetailAffinityButton.followIdle,
          label: 'Segui',
          tooltip: 'Segui',
          buildControl: (context, compact) => DetailAffinityButton(
            iconOnly: compact,
            isActive: false,
            idleIcon: DetailAffinityButton.followIdle,
            activeIcon: DetailAffinityButton.followActive,
            idleLabel: 'Segui',
            activeLabel: 'Seguito',
            activeColor: DetailAffinityButton.brandColor(
              Theme.of(context).colorScheme,
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  testWidgets(
    'wide DetailActionsBar splits Play+Save left and utilities right',
    (tester) async {
      await pump(tester, buildBar(), const Size(1280, 800));
      expect(tester.takeException(), isNull);

      final playPos = tester.getTopLeft(find.text('Riproduci brani popolari'));
      final followPos = tester.getTopLeft(find.text('Segui'));
      final shufflePos = tester.getTopLeft(find.byIcon(LucideIcons.shuffle));
      final queuePos = tester.getTopLeft(find.byIcon(LucideIcons.listMusic));
      final morePos = tester.getTopLeft(find.byIcon(LucideIcons.moreVertical));

      expect(playPos.dx, lessThan(followPos.dx));
      expect(followPos.dx, lessThan(shufflePos.dx));
      expect(shufflePos.dx, lessThan(queuePos.dx));
      expect(queuePos.dx, lessThan(morePos.dx));
      expect(morePos.dx, greaterThan(900));
    },
  );

  testWidgets(
    'compact DetailActionsBar renders Play + icon affinity left without overflow',
    (tester) async {
      await pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: buildBar(),
        ),
        const Size(360, 800),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('Segui'), findsNothing);
      final playPos = tester.getTopLeft(find.byIcon(LucideIcons.play));
      final followIconPos = tester.getTopLeft(
        find.byIcon(DetailAffinityButton.followIdle),
      );
      final shufflePos = tester.getTopLeft(find.byIcon(LucideIcons.shuffle));

      expect(playPos.dx, lessThan(followIconPos.dx));
      expect(followIconPos.dx, lessThan(shufflePos.dx));
    },
  );

  testWidgets(
    'utility pill uses theme ColorScheme tokens without hardcoded colors',
    (tester) async {
      const customSurfaceLowest = Color(0xFF123456);
      const customOutline = Color(0xFF654321);
      final customScheme = const ColorScheme.dark().copyWith(
        surfaceContainerLowest: customSurfaceLowest,
        outlineVariant: customOutline,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.from(colorScheme: customScheme),
          home: Scaffold(body: buildBar()),
        ),
      );
      await tester.pump();

      final pillDecorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(DetailActionsBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(
        pillDecorations.any(
          (d) => d.color == customSurfaceLowest.withValues(alpha: 0.86),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'photo EntityBannerHeader renders clean banner without inner title',
    (tester) async {
      final lightScheme = const ColorScheme.light().copyWith(
        surface: const Color(0xFFF5F7FB),
        onSurface: const Color(0xFF0F172A),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.from(colorScheme: lightScheme)
                .copyWith(extensions: [PlayerColors.standard()]),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: EntityBannerHeader.expandedHeight(
                      wide: true,
                      layout: EntityBannerLayout.photo,
                    ),
                    flexibleSpace: const FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: EntityBannerHeader(
                        layout: EntityBannerLayout.photo,
                        title: 'SZA',
                        placeholderIcon: LucideIcons.user,
                        scrollProgress: 0,
                        wide: true,
                        contentWidth: 1280,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('SZA'), findsNothing);
      expect(
        EntityBannerHeader.expandedHeight(
          wide: true,
          layout: EntityBannerLayout.photo,
        ),
        kToolbarHeight + 224.0,
      );
    },
  );

  testWidgets(
    'centered EntityBannerHeader and EntitySliverAppBar use light theme onSurface',
    (tester) async {
      final lightScheme = const ColorScheme.light().copyWith(
        surface: const Color(0xFFF5F7FB),
        onSurface: const Color(0xFF0F172A),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.from(colorScheme: lightScheme)
                .copyWith(extensions: [PlayerColors.standard()]),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  EntitySliverAppBar(
                    expandedHeight: EntityBannerHeader.expandedHeight(
                      wide: false,
                      layout: EntityBannerLayout.centered,
                    ),
                    scrollProgress: 0,
                    collapsedTitle: const Text('Echoes'),
                    background: const EntityBannerHeader(
                      layout: EntityBannerLayout.centered,
                      title: 'Echoes',
                      placeholderIcon: LucideIcons.disc,
                      scrollProgress: 0,
                      wide: false,
                      contentWidth: 400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(EntityBannerHeader),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Echoes',
          ),
        ),
      );
      expect(richText.text.style?.color, lightScheme.onSurface);
    },
  );
}
