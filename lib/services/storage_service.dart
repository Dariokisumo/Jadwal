import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences. The whole app only ever
/// persists one thing: the validated timetable JSON blob, plus a
/// boolean flag marking whether setup is complete.
class StorageService {
  static const _jsonKey = 'timetable_json';
  static const _loadedKey = 'timetable_loaded';
  static const _themeKey = 'theme_mode';
  static const _overridesPrefix = 'finished_overrides_';
  static const _accentKey = 'accent_name';

  static Future<void> saveTimetable(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jsonKey, jsonEncode(data));
    await prefs.setBool(_loadedKey, true);
  }

  static Future<Map<String, dynamic>?> loadTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jsonKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Corrupted stored data should never crash the app on launch.
      return null;
    }
  }

  static Future<bool> isTimetableLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_loadedKey) ?? false;
    // Double-check the actual data is readable, not just the flag.
    if (flag) {
      final data = await loadTimetable();
      return data != null;
    }
    return false;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jsonKey);
    await prefs.remove(_loadedKey);
    // Clear all finished override keys.
    final keys = prefs.getKeys().where((k) => k.startsWith(_overridesPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> saveFinishedOverrides(
      String dayKey, List<int> periodNumbers) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_overridesPrefix$dayKey';
    final encoded = jsonEncode(periodNumbers);
    await prefs.setString(key, encoded);
  }

  static Future<List<int>> loadFinishedOverrides(String dayKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_overridesPrefix$dayKey';
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e as int).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  static Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  static Future<void> saveAccent(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, name);
  }

  static Future<String> loadAccent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accentKey) ?? 'default';
  }
}
