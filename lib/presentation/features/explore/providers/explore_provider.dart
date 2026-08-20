import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';
import '../../../providers/settings_provider.dart';

class ChartsCountryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? country) => state = country;
}

/// Override for charts country; `null` falls back to settings `gl`.
final chartsCountryOverrideProvider =
    NotifierProvider<ChartsCountryNotifier, String?>(ChartsCountryNotifier.new);

final chartsProvider = FutureProvider<ChartsResult>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  final override = ref.watch(chartsCountryOverrideProvider);
  final gl = ref.watch(settingsProvider.select((s) => s.gl));
  return repo.getCharts(country: override ?? gl);
});

final moodCategoriesProvider = FutureProvider<MoodCategoriesResult>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getMoodCategories();
});

final moodPlaylistsProvider =
    FutureProvider.family<List<PlaylistDetailed>, String>((ref, params) {
      final repo = ref.watch(musicRepositoryProvider);
      return repo.getMoodPlaylists(params);
    });

final exploreNewReleasesProvider = FutureProvider<NewReleasesResult>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getNewReleases();
});
