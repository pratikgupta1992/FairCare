/// [KeyValueStore] backed by shared_preferences — the one place the
/// app touches that plugin.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _instance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _instance()).setString(key, value);
}
