import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../domain/repositories/music_repository.dart';
import '../../../providers/settings_provider.dart';

/// Short-lived in-memory cache so Back navigation inside Android Auto's Home
/// and Explore tabs does not re-fire multiple Innertube calls.
class AaBrowseCache {
  final MusicRepository _musicRepo;
  final SharedPreferences? _prefs;
  final Duration _ttl;
  final DateTime Function() _now;

  _TimedEntry<BrowseHomeResult>? _home;
  _TimedEntry<ChartsResult>? _charts;
  _TimedEntry<MoodCategoriesResult>? _moods;
  _TimedEntry<NewReleasesResult>? _newReleases;
  final Map<String, _TimedEntry<BrowseHomeResult>> _homeByParams = {};

  AaBrowseCache({
    required this._musicRepo,
    this._prefs,
    this._ttl = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String _localeStamp() {
    final gl = _prefs?.getString(kGlKey) ?? 'US';
    final hl = _prefs?.getString(kHlKey) ?? 'en';
    return '$gl|$hl';
  }

  void clear() {
    _home = null;
    _charts = null;
    _moods = null;
    _newReleases = null;
    _homeByParams.clear();
  }

  bool _isFresh<T>(_TimedEntry<T>? entry, String stamp) {
    if (entry == null) return false;
    if (entry.stamp != stamp) return false;
    return _now().difference(entry.storedAt) < _ttl;
  }

  Future<BrowseHomeResult> getHome({String? params}) async {
    final stamp = _localeStamp();
    if (params != null && params.isNotEmpty) {
      final cached = _homeByParams[params];
      if (_isFresh(cached, stamp)) return cached!.value;
      final value = await _musicRepo.getHome(params: params);
      _homeByParams[params] = _TimedEntry(value, _now(), stamp);
      return value;
    }
    if (_isFresh(_home, stamp)) return _home!.value;
    final value = await _musicRepo.getHome();
    _home = _TimedEntry(value, _now(), stamp);
    return value;
  }

  Future<ChartsResult> getCharts() async {
    final stamp = _localeStamp();
    if (_isFresh(_charts, stamp)) return _charts!.value;
    final value = await _musicRepo.getCharts();
    _charts = _TimedEntry(value, _now(), stamp);
    return value;
  }

  Future<MoodCategoriesResult> getMoodCategories() async {
    final stamp = _localeStamp();
    if (_isFresh(_moods, stamp)) return _moods!.value;
    final value = await _musicRepo.getMoodCategories();
    _moods = _TimedEntry(value, _now(), stamp);
    return value;
  }

  Future<NewReleasesResult> getNewReleases() async {
    final stamp = _localeStamp();
    if (_isFresh(_newReleases, stamp)) return _newReleases!.value;
    final value = await _musicRepo.getNewReleases();
    _newReleases = _TimedEntry(value, _now(), stamp);
    return value;
  }
}

class _TimedEntry<T> {
  final T value;
  final DateTime storedAt;
  final String stamp;

  const _TimedEntry(this.value, this.storedAt, this.stamp);
}
