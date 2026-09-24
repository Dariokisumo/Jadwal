import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_timetable.dart';
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
  static const _savedTimetablesKey = 'saved_timetables_library';
  static const _activeTimetableIdKey = 'active_saved_timetable_id';

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
      maxFromTimetable = maxPeriodFromDays(timetable['timetable'] as Map);
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

  /// ponytail: ONE shared max-period scan (also used by EditTimetableController).
  static int maxPeriodFromDays(Map days) {
    var maxP = 0;
    for (final dayList in days.values) {
      if (dayList is List) {
        for (final item in dayList) {
          if (item is Map && item['period'] != null) {
            final p = item['period'];
            final n = p is int ? p : int.tryParse(p.toString()) ?? 0;
            if (n > maxP) maxP = n;
          }
        }
      }
    }
    return maxP;
  }

  // ponytail: one fallback builder; [save] preserves the original
  // raw==null (saved) vs empty/corrupt (unsaved) distinction.
  static Future<List<TimingProfile>> _defaultWithSave({
    int? periodCount,
    Map<String, dynamic>? timetable,
    bool save = true,
  }) async {
    final count = periodCount ?? await loadPeriodCount();
    final tt = timetable ?? await loadTimetable();
    final initial = [
      TimingProfile.defaultProfile(periodCount: count, timetable: tt)
    ];
    if (save) await saveTimingProfiles(initial);
    return initial;
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
      return _defaultWithSave(periodCount: periodCount, timetable: timetable);
    }
    try {
      final decoded = jsonDecode(raw) as List;
      final profiles = decoded
          .map((e) => TimingProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (profiles.isEmpty) {
        return _defaultWithSave(
            periodCount: periodCount, timetable: timetable, save: false);
      }
      return profiles;
    } catch (_) {
      return _defaultWithSave(
          periodCount: periodCount, timetable: timetable, save: false);
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

  static Future<TimingProfile> importTimingProfile(TimingProfile profile) async {
    final profiles = await loadTimingProfiles();
    
    // Disambiguate name if already exists
    var candidateName = profile.name;
    var suffix = 1;
    while (profiles.any((p) => p.name.toLowerCase() == candidateName.toLowerCase())) {
      candidateName = '${profile.name} ($suffix)';
      suffix++;
    }

    final imported = profile.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: candidateName,
    );

    profiles.add(imported);
    await saveTimingProfiles(profiles);
    return imported;
  }

  static const _dismissedClipboardKey = 'dismissed_clipboard_hashes';

  /// Checks if the given clipboard text has already been dismissed or imported
  /// by the user so we don't nag them repeatedly.
  static Future<bool> isClipboardTextDismissed(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedClipboardKey) ?? [];
    final hash = text.hashCode.toString();
    return dismissed.contains(hash);
  }

  /// Marks the clipboard text as dismissed or handled.
  static Future<void> markClipboardTextDismissed(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedClipboardKey) ?? [];
    final hash = text.hashCode.toString();
    if (!dismissed.contains(hash)) {
      dismissed.add(hash);
      // Keep up to 50 recent hashes to prevent unbounded growth
      if (dismissed.length > 50) {
        dismissed.removeAt(0);
      }
      await prefs.setStringList(_dismissedClipboardKey, dismissed);
    }
  }

  // ==========================================
  // SAVED TIMETABLES LIBRARY
  // ==========================================

  /// Saves the full list of saved timetable profiles to persistent storage.
  static Future<void> saveSavedTimetables(List<SavedTimetable> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = list.map((item) => item.toJson()).toList();
    await prefs.setString(_savedTimetablesKey, jsonEncode(encoded));
  }

  /// Loads the list of saved timetable profiles.
  /// If the library is empty but a live timetable is loaded, it automatically
  /// seeds an initial profile so the user's current schedule is safe.
  static Future<List<SavedTimetable>> loadSavedTimetables() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedTimetablesKey);

    if (raw == null || raw.trim().isEmpty) {
      return _seedFromLive();
    }

    try {
      final decoded = jsonDecode(raw) as List;
      final list = decoded
          .map((item) => SavedTimetable.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        return _seedFromLive();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // ponytail: one seed helper for both empty-library branches.
  static Future<List<SavedTimetable>> _seedFromLive() async {
    final current = await loadTimetable();
    if (current == null) return [];
    final teacher = current['teacher'] as String? ?? 'Teacher';
    final initial = [
      SavedTimetable(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '$teacher\'s Timetable',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        data: current,
      ),
    ];
    await saveSavedTimetables(initial);
    await saveActiveTimetableId(initial.first.id);
    return initial;
  }

  /// Persists the ID of the currently active saved timetable.
  static Future<void> saveActiveTimetableId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTimetableIdKey, id);
  }

  /// Returns the ID of the currently active saved timetable.
  static Future<String?> loadActiveTimetableId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeTimetableIdKey);
  }

  /// Activates the given saved timetable: sets it as live timetable in storage,
  /// updates the active ID, and marks it loaded.
  static Future<void> activateTimetable(SavedTimetable timetable) async {
    await saveTimetable(timetable.data);
    await saveActiveTimetableId(timetable.id);
  }

  /// Saves the current live timetable snapshot as a new entry in the library.
  static Future<SavedTimetable?> saveCurrentLiveTimetableAs(String name) async {
    final current = await loadTimetable();
    if (current == null) return null;

    final library = await loadSavedTimetables();
    final newEntry = SavedTimetable(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isNotEmpty ? name.trim() : 'Saved Timetable',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      data: current,
    );

    library.insert(0, newEntry);
    await saveSavedTimetables(library);
    await saveActiveTimetableId(newEntry.id);
    return newEntry;
  }
}
