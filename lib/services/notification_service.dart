import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/timetable_prompt.dart';
import '../constants/weekday_map.dart';
import '../models/period_model.dart';

/// Maps day keys to Dart [DateTime] weekday constants.
/// Derived from the inverse in [kWeekdayMap] (DateTime weekday -> day key).
final Map<String, int> _weekdayMap = {
  for (final entry in kWeekdayMap.entries) entry.value: entry.key,
};

/// Returns the first occurrence of [weekday] at [hour]:[minute] in the
/// app's local timezone that is strictly after [now]. If that exact moment
/// has already passed (or is today but earlier), advances to the following
/// week so the alarm is never scheduled in the past.
tz.TZDateTime _nextWeeklyOccurrence(
  int weekday,
  int hour,
  int minute,
  tz.TZDateTime now,
) {
  var date =
      tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
  final daysAhead = (weekday - now.weekday) % 7;
  if (daysAhead > 0) {
    date = date.add(Duration(days: daysAhead));
  }
  if (!date.isAfter(now)) {
    date = date.add(const Duration(days: 7));
  }
  return date;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Must be called once before any other method, ideally in main()
  /// before runApp().
  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback if native timezone fetch fails
      tz.setLocalLocation(tz.local);
    }

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: payload=${response.payload}');
        },
      );
    } catch (e, stack) {
      debugPrint('NotificationService.init: plugin initialize failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    // Try to get notification permission immediately on startup
    if (Platform.isAndroid) {
      try {
        final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      } catch (e) {
        debugPrint(
            'NotificationService.init: requestNotificationsPermission failed: $e');
      }
      // Exact-alarm and battery-optimization permissions are intentionally
      // NOT requested here. They prompt only on explicit user action via
      // requestExactAlarmPermission() (called from the screens), so we don't
      // pester the user on every launch.
    }

    _initialized = true;
  }

  /// Requests notification permission on Android 13+ and iOS.
  /// Returns true if granted (or not required on this platform/version).
  static Future<bool> requestPermission() => requestNotificationPermission();

  /// Requests notification permission specifically.
  /// Returns `true` if granted, `false` if denied.
  /// If permanently denied, the runtime dialog won't show —
  /// the caller must direct the user to system settings.
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    // If permanently denied, the runtime dialog won't show —
    // the caller must direct the user to system settings.
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Quick check: are notification permissions granted?
  static Future<bool> arePermissionsGranted() async {
    try {
      final notif = await Permission.notification.status;
      return notif.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Checks if exact alarm permission (SCHEDULE_EXACT_ALARM) is granted.
  /// On Android 14+ (API 34+), this is a special permission that must be
  /// explicitly granted by the user in system settings.
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      const channel = MethodChannel('com.jadwal/exact_alarm');
      final result = await channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? false;
    } catch (_) {
      // Fallback: assume not available on older Android versions
      return true;
    }
  }

  /// Opens the system settings page for exact alarm permission.
  /// On Android 14+, users must manually enable "Alarms & reminders".
  /// Returns `true` if permission is now granted, `false` otherwise.
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      // First check if already granted
      if (await hasExactAlarmPermission()) return true;

      // Request via platform channel
      const channel = MethodChannel('com.jadwal/exact_alarm');
      final result = await channel.invokeMethod<bool>('requestExactAlarm');
      if (result == true) return true;

      // Fallback: open app settings so user can find Alarms & reminders
      await openAppSettings();

      return await hasExactAlarmPermission();
    } catch (e, stack) {
      debugPrint('NotificationService.requestExactAlarmPermission failed: $e');
      debugPrintStack(stackTrace: stack);
      // If channel fails, try opening settings directly
      try {
        await openAppSettings();
        return await hasExactAlarmPermission();
      } catch (e2, stack2) {
        debugPrint(
            'NotificationService.requestExactAlarmPermission fallback failed: $e2');
        debugPrintStack(stackTrace: stack2);
        return false;
      }
    }
  }

  /// Requests that Android exempt Jadwal from battery optimization.
  ///
  /// On stock Android, exact alarms fire reliably once SCHEDULE_EXACT_ALARM
  /// is granted. On OEM skins (OnePlus/OxygenOS, Xiaomi/MIUI, Huawei/EMUI,
  /// Oppo/ColorOS, Vivo/OriginOS), the system kills background processes
  /// even when that permission is granted, silently dropping scheduled
  /// alarms. The only code-side mitigation is to ask the user to add the
  /// app to the battery-optimization allow-list.
  ///
  /// Returns `true` if battery optimization is disabled for Jadwal.
  /// If denied or restricted, opens the system battery-optimization
  /// settings page so the user can grant it manually.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        debugPrint('NotificationService: battery optimization already disabled');
        return true;
      }

      if (status.isPermanentlyDenied) {
        debugPrint(
            'NotificationService: battery optimization permanently denied — opening settings');
        await _openBatteryOptimizationSettings();
        return false;
      }

      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        debugPrint('NotificationService: battery optimization disabled by user');
        return true;
      }

      debugPrint('NotificationService: battery optimization denied by user');
      await _openBatteryOptimizationSettings();
      return false;
    } catch (e, stack) {
      debugPrint(
          'NotificationService.requestIgnoreBatteryOptimizations failed: $e');
      debugPrintStack(stackTrace: stack);
      try {
        await _openBatteryOptimizationSettings();
      } catch (_) {}
      return false;
    }
  }

  static Future<void> _openBatteryOptimizationSettings() async {
    // Best-effort: try the direct deep-link first. On OnePlus/OxygenOS
    // this is the "Battery > App battery management > Jadwal" page.
    try {
      const intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
      return;
    } catch (e) {
      debugPrint(
          'NotificationService: deep-link to battery optimization failed, falling back: $e');
    }
    // Fallback: open app details page.
    await openAppSettings();
  }

  /// Schedules recurring weekly notifications for every period across all
  /// days in the timetable. Each notification fires 5 minutes before the
  /// period starts, on the correct day of the week.
  ///
  /// Uses [DateTimeComponents.dayOfWeekAndTime] so alarms survive reboots
  /// via the [ScheduledNotificationBootReceiver] already declared in the
  /// Android manifest.
  ///
  /// Safe to call repeatedly — cancels all previous notifications first.
  static Future<void> scheduleAll(Map<String, dynamic> timetable) async {
    if (!_initialized) await init();

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.scheduleAll: cancelAll failed: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'period_reminders',
      'Period Reminders',
      channelDescription: 'Reminds you 5 minutes before each class period',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'com.jadwal.period_reminders',
      color: Color(0xFFD4930D),
      subText: 'Jadwal',
      category: AndroidNotificationCategory.reminder,
      onlyAlertOnce: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.from(DateTime.now(), tz.local);
    const scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

    for (var dayIndex = 0; dayIndex < kDayKeys.length; dayIndex++) {
      final dayKey = kDayKeys[dayIndex];
      final dayList = timetable[dayKey] as List? ?? [];
      if (dayList.isEmpty) continue;

      final weekday = _weekdayMap[dayKey];
      if (weekday == null) continue;

      for (final entry in dayList) {
        final period = Period.fromJson(entry as Map<String, dynamic>);
        final start = period.startTime;
        if (start == null) continue;

        // Compute the first upcoming occurrence of this period's 5-min-before
        // time on the *target* weekday (not today's), so each reminder fires
        // on the correct day of the week.
        final reminder = start.subtract(const Duration(minutes: 5));
        final scheduledDate = _nextWeeklyOccurrence(
          weekday,
          reminder.hour,
          reminder.minute,
          now,
        );

        // Unique ID: dayIndex (0-5) * 10 + periodNumber (1-9) → no collisions.
        final notifId = dayIndex * 10 + period.periodNumber;

        try {
          await _plugin.zonedSchedule(
            notifId,
            '⏰ Period ${period.periodNumber} starting soon',
            '${period.subject} in ${period.classroom} · ${period.start}',
            scheduledDate,
            details,
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          // If exact alarms are restricted on a given device/OS version,
          // fail quietly for that single notification rather than crash
          // the whole scheduling pass.
          debugPrint(
              'NotificationService.scheduleAll: zonedSchedule for $dayKey period ${period.periodNumber} failed: $e');
          continue;
        }
      }
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
