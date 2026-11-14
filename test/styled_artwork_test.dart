import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/theme/sonora_pulse_tokens.dart';
import 'package:sonora/domain/models/artwork_style.dart';
import 'package:sonora/presentation/features/player/widgets/artwork.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/styled_artwork.dart';
import 'package:sonora/presentation/shared/widgets/thumbnail_widget.dart';

class _StillSettings extends SettingsNotifier {
  @override
  Settings build() => const Settings(reduceEffects: true);
}

class _BarsSettings extends SettingsNotifier {
  @override
  Settings build() =>
      const Settings(reduceEffects: true, artworkStyle: ArtworkStyle.bars);
}

class _FrozenPlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState(isPlaying: false);
}

void main() {
  test('storage names round-trip and unknown values stay on vinyl', () {
    expect(ArtworkStyle.fromStorage('pulse'), ArtworkStyle.pulse);
    expect(ArtworkStyle.fromStorage('bars'), ArtworkStyle.bars);
    expect(ArtworkStyle.fromStorage('plain'), ArtworkStyle.plain);
    expect(ArtworkStyle.fromStorage(null), ArtworkStyle.vinyl);
    expect(ArtworkStyle.fromStorage('cd'), ArtworkStyle.vinyl);
    expect(ArtworkStyle.pulse.storageValue, 'pulse');
  });

  test('the legacy bool maps off to the plain cover', () {
    expect(ArtworkStyle.fromLegacyBool(false), ArtworkStyle.plain);
    expect(ArtworkStyle.fromLegacyBool(true), ArtworkStyle.vinyl);
    expect(ArtworkStyle.fromLegacyBool(null), ArtworkStyle.vinyl);
  });

  test('episodes keep the plain cover', () {
    expect(ArtworkStyle.bars.forPlayback(isEpisode: true), ArtworkStyle.plain);
    expect(
      ArtworkStyle.pulse.forPlayback(isEpisode: false),
      ArtworkStyle.pulse,
    );
  });

  testWidgets('pulse keeps a full-size circular cover and an arc', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_StillSettings.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: PulseArtwork(
              imageUrl: null,
              size: 180,
              isPlaying: true,
              circular: true,
            ),
          ),
        ),
      ),
    );

    final thumb = tester.widget<ThumbnailWidget>(find.byType(ThumbnailWidget));
    expect(thumb.size, 180);
    expect(thumb.shape, ThumbnailShape.circle);
    expect(find.byKey(const ValueKey('pulse-arc')), findsOneWidget);
  });

  testWidgets('mini pulse uses the 12px cover radius', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_StillSettings.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: PulseArtwork(
              imageUrl: null,
              size: 48,
              isPlaying: false,
              circular: false,
              cornerRadius: 12,
            ),
          ),
        ),
      ),
    );

    final thumb = tester.widget<ThumbnailWidget>(find.byType(ThumbnailWidget));
    expect(thumb.shape, ThumbnailShape.rounded);
    expect(thumb.borderRadius, 12);
  });

  testWidgets('bars clip the cover and rest while paused', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_StillSettings.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: BarsArtwork(
              imageUrl: null,
              size: 200,
              isPlaying: false,
              cornerRadius: 24,
            ),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ClipRRect &&
            widget.borderRadius == BorderRadius.circular(24),
      ),
    );
    expect(clip.borderRadius, BorderRadius.circular(24));

    final bars = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == SonoraPulseTokens.primaryContainer;
    });
    expect(bars, findsNWidgets(5));
    final heights = tester
        .widgetList(bars)
        .map((bar) => tester.getSize(find.byWidget(bar)).height)
        .toSet();
    expect(heights, {200 * 0.07});
  });

  testWidgets('the full-player thumb uses the mini cover radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_BarsSettings.new),
          playerStateProvider.overrideWith(_FrozenPlayer.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Artwork(artUrl: null, size: 56, videoId: 'thumb', mini: true),
          ),
        ),
      ),
    );

    final radii = tester
        .widgetList<ClipRRect>(find.byType(ClipRRect))
        .map((clip) => clip.borderRadius)
        .toList();
    expect(radii, contains(BorderRadius.circular(SonoraPulseTokens.radiusSm)));
    expect(
      radii,
      isNot(contains(BorderRadius.circular(SonoraPulseTokens.radiusMedia))),
    );
  });
}
