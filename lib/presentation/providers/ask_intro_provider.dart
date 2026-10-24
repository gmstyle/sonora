import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Pure visibility rule for the one-shot Ask intro wizard.
bool shouldShowAiIntro({required bool seen}) => !seen;

/// Whether the Ask feature intro should be shown after home settles.
final shouldShowAiIntroProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final seen = prefs.getBool(kAiIntroSeenKey) ?? false;
  return shouldShowAiIntro(seen: seen);
});
