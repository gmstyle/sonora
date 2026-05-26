import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_master/palette_generator_master.dart';

class PaletteData {
  final Color dominantColor;
  final bool isDark;

  const PaletteData({required this.dominantColor, required this.isDark});
}

class PaletteNotifier extends Notifier<Map<String, PaletteData>> {
  @override
  Map<String, PaletteData> build() => {};

  Future<void> extractPalette(String id, String imageUrl) async {
    if (state.containsKey(id)) return;

    try {
      final paletteGenerator = await PaletteGeneratorMaster.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 20,
      );

      final dominantColor =
          paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          paletteGenerator.mutedColor?.color ??
          Colors.black87;

      final isDark =
          ThemeData.estimateBrightnessForColor(dominantColor) ==
          Brightness.dark;

      state = {
        ...state,
        id: PaletteData(dominantColor: dominantColor, isDark: isDark),
      };
    } catch (e) {
      // In caso di errore (es. immagine non trovata/CORS), usa colore fallback
      state = {
        ...state,
        id: const PaletteData(dominantColor: Colors.black87, isDark: true),
      };
    }
  }
}

final paletteNotifierProvider =
    NotifierProvider<PaletteNotifier, Map<String, PaletteData>>(() {
      return PaletteNotifier();
    });
