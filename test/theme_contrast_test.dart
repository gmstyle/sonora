import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/core/theme/app_theme.dart';
import 'package:sonora/core/theme/sonora_pulse_tokens.dart';

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

  test('light FAB still uses dark glyph on brand cyan', () {
    final theme = AppTheme.light();
    expect(
      theme.floatingActionButtonTheme.foregroundColor,
      SonoraPulseTokens.onPrimary,
    );
    expect(theme.filledButtonTheme.style?.backgroundColor, isNull);
  });
}
