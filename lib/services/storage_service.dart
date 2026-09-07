import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timing_profile.dart';

/// Thin wrapper around SharedPreferences. Persists timetable data,
/// period count, custom timing profiles, and user preferences.
class StorageService {
  static const _jsonKey = 'timetable_json';
  static const _loadedKey = 'timetable_loaded';
  static const _themeKey = 'theme_mode';
  static const _overridesPrefix = 'finished_overrides_';
  static const _accentKey = 'accent_name';
  static const _periodCountKey = 'period_count';
  static const _timingProfilesKey = 'timing_profiles';
  static const _activeProfileIdKey = 'active_timing_profile_id';

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

  static Future<void> savePeriodCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_periodCountKey, count);
  }

  static Future<int> loadPeriodCount() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_periodCountKey);
    final timetable = await loadTimetable();
    int maxFromTimetable = 0;
    if (timetable != null && timetable['timetable'] is Map) {
      final days = timetable['timetable'] as Map;
      for (final dayList in days.values) {
        if (dayList is List) {
          for (final item in dayList) {
            if (item is Map && item['period'] != null) {
              final p = item['period'] is int
                  ? item['period'] as int
                  : int.tryParse(item['period'].toString()) ?? 0;
              if (p > maxFromTimetable) maxFromTimetable = p;
            }
          }
        }
      }
    }
    if (stored != null) {
      return stored > maxFromTimetable
          ? stored
          : (maxFromTimetable > 0 ? maxFromTimetable : stored);
    }
    return maxFromTimetable > 0
        ? (maxFromTimetable > 9 ? maxFromTimetable : 9)
        : 9;
  }

  static Future<void> saveTimingProfiles(List<TimingProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final list = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_timingProfilesKey, jsonEncode(list));
  }

  static Future<List<TimingProfile>> loadTimingProfiles({
    int? periodCount,
    Map<String, dynamic>? timetable,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timingProfilesKey);
    if (raw == null) {
      final count = periodCount ?? await loadPeriodCount();
      final tt = timetable ?? await loadTimetable();
      final initial = [
        TimingProfile.defaultProfile(periodCount: count, timetable: tt)
      ];
      await saveTimingProfiles(initial);
      return initial;
    }
    try {
      final decoded = jsonDecode(raw) as List;
      final profiles = decoded
          .map((e) => TimingProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (profiles.isEmpty) {
        final count = periodCount ?? await loadPeriodCount();
        final tt = timetable ?? await loadTimetable();
        return [
          TimingProfile.defaultProfile(periodCount: count, timetable: tt)
        ];
      }
      return profiles;
    } catch (_) {
      final count = periodCount ?? await loadPeriodCount();
      final tt = timetable ?? await loadTimetable();
      return [TimingProfile.defaultProfile(periodCount: count, timetable: tt)];
    }
  }

  static Future<void> saveActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileIdKey, id);
  }

  static Future<String?> loadActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileIdKey);
  }
}
