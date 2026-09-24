import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared `h:mm AM` time helpers (ponytail: single copy for period sheets).
DateTime? parseHmmA(String raw) {
  try {
    return DateFormat('h:mm a').parse(raw.trim());
  } catch (_) {
    return null;
  }
}

TimeOfDay parseHmmATimeOfDay(String raw, {required TimeOfDay fallback}) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s(AM|PM)$').firstMatch(raw.trim());
  if (m == null) return fallback;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final period = m.group(3);
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}

String formatHmmA(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

int? gapMinutesHmmA(String endStr, String nextStartStr) {
  final e = parseHmmA(endStr);
  final s = parseHmmA(nextStartStr);
  if (e == null || s == null) return null;
  return s.difference(e).inMinutes;
}

/// Shows a 12-hour time picker for an `h:mm AM` string. Returns the
/// formatted string, or null if cancelled.
Future<String?> pickHmmATime(
  BuildContext context,
  String current, {
  required TimeOfDay fallback,
}) async {
  final initial = parseHmmATimeOfDay(current, fallback: fallback);
  final picked = await showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      );
    },
  );
  if (picked == null) return null;
  return formatHmmA(picked);
}
