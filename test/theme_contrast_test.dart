import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/core/theme/app_theme.dart';
import 'package:sonora/core/theme/brand_accent.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/core/theme/sonora_pulse_tokens.dart';
import 'package:sonora/presentation/shared/widgets/detail_affinity_button.dart';
import 'package:sonora/presentation/shared/widgets/smart_mix_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dark ColorScheme primary is brand cyan, not ice tint', () {
    final scheme = SonoraPulseTokens.darkScheme();
    expect(scheme.primary, SonoraPulseTokens.primaryContainer);
    expect(scheme.onPrimary, SonoraPulseTokens.onPrimary);
    expect(scheme.primaryContainer, SonoraPulseTokens.primaryContainer);
    expect(scheme.onPrimaryContainer, SonoraPulseTokens.onPrimary);
    expect(SonoraPulseTokens.primaryTint, const Color(0xFFE0FDFF));
    expect(scheme.primary, isNot(SonoraPulseTokens.primaryTint));
  });

  test('AppTheme dark keeps FilledButtonTheme from painting tonal fills', () {
    final theme = AppTheme.dark();
    final scheme = theme.colorScheme;

    // Shape/padding only — colors stay on ColorScheme so tonal Follow/Like
    // keep secondaryContainer instead of brand cyan.
    expect(theme.filledButtonTheme.style?.backgroundColor, isNull);
    expect(theme.filledButtonTheme.style?.foregroundColor, isNull);
    expect(scheme.primary, SonoraPulseTokens.primaryContainer);
    expect(scheme.onPrimary, SonoraPulseTokens.onPrimary);

    expect(
      theme.floatingActionButtonTheme.backgroundColor,
      scheme.primaryContainer,
    );
    expect(
      theme.floatingActionButtonTheme.foregroundColor,
      SonoraPulseTokens.onPrimary,
    );

    final elevatedBg = theme.elevatedButtonTheme.style?.backgroundColor
        ?.resolve({});
    final elevatedFg = theme.elevatedButtonTheme.style?.foregroundColor
        ?.resolve({});
    expect(elevatedBg, scheme.primaryContainer);
    expect(elevatedFg, SonoraPulseTokens.onPrimary);

    final textFg = theme.textButtonTheme.style?.foregroundColor?.resolve({});
    expect(textFg, SonoraPulseTokens.primaryTint);
  });

  test('selection controls use brand primary, and like matches them', () {
    final theme = AppTheme.dark();
    final scheme = theme.colorScheme;
    final labelColor = theme.chipTheme.labelStyle?.color;

    expect(
      WidgetStateProperty.resolveAs<Color?>(labelColor, const {}),
      scheme.onSurfaceVariant,
    );
    expect(
      WidgetStateProperty.resolveAs<Color?>(labelColor, {WidgetState.selected}),
      scheme.primary,
    );
    expect(
      theme.chipTheme.selectedColor,
      scheme.primaryContainer.withValues(alpha: 0.28),
    );
    expect(theme.chipTheme.showCheckmark, isFalse);
    expect(theme.chipTheme.secondaryLabelStyle?.color, scheme.primary);

    final segmented = theme.segmentedButtonTheme.style;
    expect(
      segmented?.backgroundColor?.resolve({WidgetState.selected}),
      scheme.primaryContainer.withValues(alpha: 0.28),
    );
    expect(
      segmented?.foregroundColor?.resolve({WidgetState.selected}),
      scheme.primary,
    );
    expect(
      segmented?.foregroundColor?.resolve(const {}),
      scheme.onSurfaceVariant,
    );

    expect(DetailAffinityButton.likeColor(scheme), scheme.primary);
    expect(
      DetailAffinityButton.likeColor(scheme),
      DetailAffinityButton.brandColor(scheme),
    );
    expect(DetailAffinityButton.likeColor(scheme), isNot(scheme.error));
  });

  test('a non-cyan accent recolors fills and leaves the surface', () {
    final scheme = SonoraPulseTokens.darkScheme(BrandAccent.violet);
    final theme = AppTheme.dark(BrandAccent.violet);
    expect(scheme.primary, BrandAccent.violet.fill);
    expect(scheme.onPrimary, BrandAccent.violet.ink);
    expect(scheme.surface, SonoraPulseTokens.surface);
    expect(scheme.secondaryContainer, SonoraPulseTokens.secondaryContainer);
    expect(
      theme.floatingActionButtonTheme.backgroundColor,
      BrandAccent.violet.fill,
    );
    expect(
      theme.floatingActionButtonTheme.foregroundColor,
      BrandAccent.violet.ink,
    );
    expect(theme.extension<PlayerColors>()?.accent, BrandAccent.violet.fill);
    expect(theme.extension<PlayerColors>()?.accentEnd, BrandAccent.violet.end);
  });

  test('appearance offers twelve distinct brand accents', () {
    expect(BrandAccent.values, hasLength(12));
    expect(
      BrandAccent.values.map((accent) => accent.fill).toSet(),
      hasLength(12),
    );
    expect(BrandAccent.fromStorage('lime'), BrandAccent.lime);
    expect(BrandAccent.fromStorage('nope'), BrandAccent.cyan);
  });

  test('smart mix cards follow the accent and keep cyan treatments', () {
    final cyanMost = smartMixGradientFor(SmartMixType.mostPlayed);
    expect(cyanMost.colors.first, SonoraPulseTokens.gradientStart);
    expect(cyanMost.colors.last, SonoraPulseTokens.accentElectricBlue);

    final violet = BrandAccent.violet;
    final forgotten = smartMixGradientFor(
      SmartMixType.forgottenFavorites,
      fill: violet.fill,
      end: violet.end,
      ink: violet.ink,
    );
    expect(forgotten.colors.first, violet.fill);
    expect(forgotten.colors.last, violet.end);

    final most = smartMixGradientFor(
      SmartMixType.mostPlayed,
      fill: violet.fill,
      end: violet.end,
      ink: violet.ink,
    );
    expect(most.colors.first, violet.fill);
    expect(most.colors.last, isNot(SonoraPulseTokens.accentElectricBlue));
  });

  test('light FAB still uses dark glyph on brand cyan', () {
    final theme = AppTheme.light();
    expect(
      theme.floatingActionButtonTheme.foregroundColor,
      SonoraPulseTokens.onPrimary,
    );
    expect(theme.filledButtonTheme.style?.backgroundColor, isNull);
  });
}
