import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed, centralized boundary around [SharedPreferences].
///
/// Ensures domain callers perform type-safe synchronous reads and asynchronous
/// writes against disk storage. Direct raw access is scoped to testing.
class AppPreferencesService {
  final SharedPreferences _prefs;

  AppPreferencesService(this._prefs);

  /// Access to the underlying raw [SharedPreferences] instance.
  ///
  /// Strictly restricted to tests or low-level platform bridges to prevent
  /// bypassing the typed contract.
  @visibleForTesting
  SharedPreferences get rawPrefs => _prefs;

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  int getInt(String key, {int defaultValue = 0}) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  Future<bool> setInt(String key, int value) {
    return _prefs.setInt(key, value);
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  Future<bool> setDouble(String key, double value) {
    return _prefs.setDouble(key, value);
  }

  String getString(String key, {String defaultValue = ''}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  List<String> getStringList(
    String key, {
    List<String> defaultValue = const [],
  }) {
    return _prefs.getStringList(key) ?? defaultValue;
  }

  Future<bool> setStringList(String key, List<String> value) {
    return _prefs.setStringList(key, value);
  }

  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  Set<String> getKeys() {
    return _prefs.getKeys();
  }
}
