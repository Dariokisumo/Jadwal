import 'dart:convert';

import '../constants/timetable_prompt.dart';

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  ValidationResult.success(this.data)
      : isValid = true,
        errorMessage = null;

  ValidationResult.failure(this.errorMessage)
      : isValid = false,
        data = null;
}

/// Validates and normalizes the structure of an imported timetable JSON before
/// it is ever trusted by the rest of the app.
///
/// Automatically heals common AI output discrepancies:
/// - Missing day keys (fills missing days from [kDayKeys] with empty lists `[]`)
/// - Case-insensitive day keys (`"Saturday"` -> `"saturday"`)
/// - Alternate teacher field names (`"teacher_name"`, `"name"`)
/// - Unspaced time formats (`"2:00PM"` -> `"2:00 PM"`)
/// - 24-hour time formats (`"14:00"` -> `"2:00 PM"`)
/// - Leading zero normalization (`"08:00 AM"` -> `"8:00 AM"`)
/// - String period numbers (`"1"` -> `1`)
class JsonValidator {
  /// Strips markdown code block fences and extracts the outermost JSON object
  /// from raw AI response text.
  static String sanitizeJson(String raw) {
    var s = raw.trim();

    // Strip markdown code block fences if present: ```json ... ``` or ``` ... ```
    if (s.contains('```')) {
      final startFence = s.indexOf('```');
      final afterFirstFence = s.indexOf('\n', startFence);
      if (afterFirstFence != -1) {
        final endFence = s.lastIndexOf('```');
        if (endFence > afterFirstFence) {
          s = s.substring(afterFirstFence + 1, endFence).trim();
        }
      }
    }

    // Extract outermost JSON object if surrounded by chat or explanation text
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s.trim();
  }

  /// Attempts to sanitize, parse, and validate/normalize a raw JSON string.
  /// Returns the validated [Map<String, dynamic>] if successful, or null.
  static Map<String, dynamic>? tryParseAndNormalize(String raw) {
    try {
      final cleaned = sanitizeJson(raw);
      if (!cleaned.startsWith('{') || !cleaned.endsWith('}')) return null;
      final decoded = jsonDecode(cleaned);
      final result = validate(decoded);
      return result.isValid ? result.data : null;
    } catch (_) {
      return null;
    }
  }

  /// Normalizes a time string to standard `h:mm AM/PM` 12-hour format with single space.
  ///
  /// Supports:
  /// - 12-hour with or without space: "2:00 PM", "2:00PM", "02:00 pm", "2:00am"
  /// - 24-hour military format: "14:00", "08:30", "0:00"
  /// Returns null if the format cannot be recognized as a valid time.
  static String? normalizeTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1. Check for 12-hour pattern (with or without space, case-insensitive)
    final regex12 = RegExp(r'^0?(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)$');
    final match12 = regex12.firstMatch(s);
    if (match12 != null) {
      final hour = int.tryParse(match12.group(1)!);
      final min = int.tryParse(match12.group(2)!);
      final period = match12.group(3)!.toUpperCase();
      if (hour == null || hour < 1 || hour > 12) return null;
      if (min == null || min < 0 || min > 59) return null;
      final minStr = min.toString().padLeft(2, '0');
      return '$hour:$minStr $period';
    }

    // 2. Check for 24-hour pattern: "14:00", "08:30", "0:00"
    final regex24 = RegExp(r'^0?(\d{1,2}):(\d{2})$');
    final match24 = regex24.firstMatch(s);
    if (match24 != null) {
      final h24 = int.tryParse(match24.group(1)!);
      final min = int.tryParse(match24.group(2)!);
      if (h24 == null || h24 < 0 || h24 > 23) return null;
      if (min == null || min < 0 || min > 59) return null;

      final String period;
      final int h12;
      if (h24 == 0) {
        h12 = 12;
        period = 'AM';
      } else if (h24 < 12) {
        h12 = h24;
        period = 'AM';
      } else if (h24 == 12) {
        h12 = 12;
        period = 'PM';
      } else {
        h12 = h24 - 12;
        period = 'PM';
      }
      final minStr = min.toString().padLeft(2, '0');
      return '$h12:$minStr $period';
    }

    return null;
  }

  /// Validates and heals the structure of an imported timetable JSON before it
  /// is ever trusted by the rest of the app.
  static ValidationResult validate(dynamic decoded) {
    if (decoded is! Map) {
      return ValidationResult.failure(
        'The file does not contain a JSON object at the top level.',
      );
    }

    final rawJson = Map<String, dynamic>.from(decoded);

    // 1. Resolve teacher name (support synonyms: teacher, teacher_name, teacherName, name)
    String teacher = '';
    if (rawJson.containsKey('teacher') && rawJson['teacher'] != null) {
      teacher = rawJson['teacher'].toString().trim();
    } else if (rawJson.containsKey('teacher_name') && rawJson['teacher_name'] != null) {
      teacher = rawJson['teacher_name'].toString().trim();
    } else if (rawJson.containsKey('teacherName') && rawJson['teacherName'] != null) {
      teacher = rawJson['teacherName'].toString().trim();
    } else if (rawJson.containsKey('name') && rawJson['name'] != null) {
      teacher = rawJson['name'].toString().trim();
    }

    if (teacher.isEmpty) {
      teacher = 'Teacher'; // Graceful default rather than rejecting the entire timetable
    }

    // 2. Validate timetable object
    if (!rawJson.containsKey('timetable') || rawJson['timetable'] is! Map) {
      return ValidationResult.failure(
        'Missing or invalid "timetable" field (expected an object).',
      );
    }

    final rawTimetable = rawJson['timetable'] as Map;
    final Map<String, dynamic> normalizedTimetable = {};

    // Build a case-insensitive lookup for raw timetable keys
    final Map<String, dynamic> lowercaseTimetableLookup = {};
    for (final entry in rawTimetable.entries) {
      lowercaseTimetableLookup[entry.key.toString().toLowerCase().trim()] = entry.value;
    }

    // Validate and heal every day in kDayKeys
    for (final dayKey in kDayKeys) {
      final rawDayValue = lowercaseTimetableLookup[dayKey];

      // If the day is missing from the AI output, auto-heal by providing an empty list
      if (rawDayValue == null) {
        normalizedTimetable[dayKey] = <Map<String, dynamic>>[];
        continue;
      }

      if (rawDayValue is! List) {
        return ValidationResult.failure(
          'The value for "$dayKey" must be a list of periods, '
          'but something else was found.',
        );
      }

      final List<Map<String, dynamic>> normalizedPeriods = [];
      for (var i = 0; i < rawDayValue.length; i++) {
        final entry = rawDayValue[i];
        final validation = _validateAndNormalizePeriodEntry(entry, dayKey, i);
        if (validation.error != null) {
          return ValidationResult.failure(validation.error!);
        }
        normalizedPeriods.add(validation.normalizedEntry!);
      }
      normalizedTimetable[dayKey] = normalizedPeriods;
    }

    final normalizedResult = <String, dynamic>{
      'teacher': teacher,
      'timetable': normalizedTimetable,
    };

    return ValidationResult.success(normalizedResult);
  }

  static ({Map<String, dynamic>? normalizedEntry, String? error})
      _validateAndNormalizePeriodEntry(dynamic entry, String dayKey, int index) {
    if (entry is! Map) {
      return (normalizedEntry: null, error: 'Entry #${index + 1} in "$dayKey" is not a valid object.');
    }

    final periodMap = Map<String, dynamic>.from(entry);

    // Validate period number
    if (!periodMap.containsKey('period')) {
      return (normalizedEntry: null, error: 'Entry #${index + 1} in "$dayKey" is missing the "period" number.');
    }
    final periodVal = periodMap['period'];
    final parsedPeriod = int.tryParse(periodVal.toString());
    if (parsedPeriod == null) {
      return (normalizedEntry: null, error: 'Entry #${index + 1} in "$dayKey" has a non-numeric "period" value.');
    }
    periodMap['period'] = parsedPeriod;

    // Validate string fields
    const requiredStringFields = ['subject', 'classroom', 'start', 'end'];
    for (final field in requiredStringFields) {
      if (!periodMap.containsKey(field) ||
          periodMap[field] == null ||
          periodMap[field].toString().trim().isEmpty) {
        return (
          normalizedEntry: null,
          error: 'Entry #${index + 1} in "$dayKey" is missing a valid "$field" value.'
        );
      }
    }

    final rawStart = periodMap['start'].toString();
    final rawEnd = periodMap['end'].toString();

    final normalizedStart = normalizeTime(rawStart);
    if (normalizedStart == null) {
      return (
        normalizedEntry: null,
        error: 'Entry #${index + 1} in "$dayKey" has an invalid "start" time '
            'format ("$rawStart"). Expected something like "2:00 PM" or "14:00".'
      );
    }

    final normalizedEnd = normalizeTime(rawEnd);
    if (normalizedEnd == null) {
      return (
        normalizedEntry: null,
        error: 'Entry #${index + 1} in "$dayKey" has an invalid "end" time '
            'format ("$rawEnd"). Expected something like "2:40 PM" or "14:40".'
      );
    }

    periodMap['start'] = normalizedStart;
    periodMap['end'] = normalizedEnd;
    periodMap['subject'] = periodMap['subject'].toString().trim();
    periodMap['classroom'] = periodMap['classroom'].toString().trim();

    return (normalizedEntry: periodMap, error: null);
  }
}
