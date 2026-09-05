import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../constants/weekday_map.dart';
import '../models/period_model.dart';

/// Service to bridge Flutter data to the Android Glance widget.
/// Uses SharedPreferences directly (not home_widget's saveWidgetData)
/// because the Glance widget reads from FlutterSharedPreferences directly.
class WidgetDataService {
  static const _widgetDataKey = 'widget_data';
  static const _platform = MethodChannel('com.jadwal/exact_alarm');

  /// Update the widget with current timetable data.
  static Future<void> updateWidget() async {
    try {
      final data = await _buildWidgetData();
      await _saveWidgetData(data);
      await HomeWidget.updateWidget(
        name: 'JadwalWidgetReceiver',
        androidName: 'JadwalWidgetReceiver',
      );
      await scheduleMidnightAlarm();
      await schedulePeriodicRefresh();
    } catch (_) {
      // Silently fail — widget updates are best-effort.
    }
  }

  /// Schedule a one-shot alarm at midnight to refresh the widget for the new day.
  static Future<void> scheduleMidnightAlarm() async {
    try {
      await _platform.invokeMethod('scheduleMidnightAlarm');
    } catch (_) {
      // Best-effort — alarm scheduling may fail on some OEMs.
    }
  }

  /// Schedule a repeating 5-minute alarm to refresh the widget throughout the day.
  static Future<void> schedulePeriodicRefresh() async {
    try {
      await _platform.invokeMethod('schedulePeriodicRefresh');
    } catch (_) {
      // Best-effort — alarm scheduling may fail on some OEMs.
    }
  }

  /// Build the widget data JSON based on current timetable state.
  static Future<Map<String, dynamic>> _buildWidgetData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('timetable_json');
    if (raw == null) {
      return {'type': 'no_timetable'};
    }

    try {
      final timetable = jsonDecode(raw) as Map<String, dynamic>;

      final now = DateTime.now();
      final dayKey = _getDayKey(now);
      final dayList = timetable['timetable'] as Map<String, dynamic>?;
      final daySchedule = dayList?[dayKey] as List<dynamic>?;

      if (daySchedule == null || daySchedule.isEmpty) {
        return {
          'type': 'no_classes_today',
          'dayName': _getDayName(now),
        };
      }

      final periods =
          daySchedule.map((e) => Period.fromJson(e as Map<String, dynamic>)).toList();

      Period? _firstWhere(bool Function(Period) test) {
        for (final p in periods) {
          if (test(p)) return p;
        }
        return null;
      }

      final current = _firstWhere((p) => p.status == PeriodStatus.active);
      final next = _firstWhere(
        (p) => p.status == PeriodStatus.upcoming && p.minutesUntilStart != null,
      );

      return {
        'type': 'today',
        'dayName': _getDayName(now),
        'periodCount': periods.length,
        'currentPeriod': current?.subject,
        'nextPeriod': next?.subject,
        'timeUntilNext': next?.minutesUntilStart != null
            ? Period.formatMinutes(next!.minutesUntilStart!)
            : null,
      };
    } catch (_) {
      return {'type': 'error', 'message': 'Failed to load timetable'};
    }
  }

  /// Lowercase day key matching the timetable JSON (e.g. 'saturday').
  static String _getDayKey(DateTime date) {
    return kWeekdayMap[date.weekday] ?? 'sunday';
  }

  /// Human-friendly day name (e.g. 'Saturday').
  static String _getDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  /// Save widget data to SharedPreferences for the Glance widget to read.
  static Future<void> _saveWidgetData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetDataKey, jsonEncode(data));
  }
}