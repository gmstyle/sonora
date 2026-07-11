import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SyncStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);
  List<String>? getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

class SharedPreferencesSyncStorage implements SyncStorage {
  final SharedPreferences prefs;
  SharedPreferencesSyncStorage(this.prefs);

  @override
  String? getString(String key) => prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      prefs.setString(key, value);

  @override
  List<String>? getStringList(String key) => prefs.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      prefs.setStringList(key, value);

  @override
  Future<void> remove(String key) => prefs.remove(key);
}

class FileSyncStorage implements SyncStorage {
  final File file;
  Map<String, dynamic> _data = {};

  FileSyncStorage(this.file) {
    if (file.existsSync()) {
      try {
        _data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }
  }

  void _save() {
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(jsonEncode(_data));
  }

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
    _save();
  }

  @override
  List<String>? getStringList(String key) {
    final list = _data[key] as List<dynamic>?;
    return list?.cast<String>();
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value;
    _save();
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
    _save();
  }
}
