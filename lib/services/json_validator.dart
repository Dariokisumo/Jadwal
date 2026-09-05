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

/// Validates the structure of an imported timetable JSON before it is
/// ever trusted by the rest of the app. Every failure path returns a
/// specific, human-readable reason rather than a generic "invalid file".
class JsonValidator {
  static ValidationResult validate(dynamic decoded) {
    if (decoded is! Map) {
      return ValidationResult.failure(
        'The file does not contain a JSON object at the top level.',
      );
    }

    final json = decoded;

    if (!json.containsKey('teacher') || json['teacher'] is! String) {
      return ValidationResult.failure(
        'Missing or invalid "teacher" field (expected a text value).',
      );
    }

    if (!json.containsKey('timetable') || json['timetable'] is! Map) {
      return ValidationResult.failure(
        'Missing or invalid "timetable" field (expected an object).',
      );
    }

    final timetable = json['timetable'] as Map;

    for (final dayKey in kDayKeys) {
      if (!timetable.containsKey(dayKey)) {
        return ValidationResult.failure(
          'The "timetable" object is missing the "$dayKey" key. '
          'All six days (saturday–thursday) must be present, '
          'even if the list is empty.',
        );
      }

      final dayValue = timetable[dayKey];
      if (dayValue is! List) {
        return ValidationResult.failure(
          'The value for "$dayKey" must be a list of periods, '
          'but something else was found.',
        );
      }

      for (var i = 0; i < dayValue.length; i++) {
        final entry = dayValue[i];
        final fieldError = _validatePeriodEntry(entry, dayKey, i);
        if (fieldError != null) {
          return ValidationResult.failure(fieldError);
        }
      }
    }

    return ValidationResult.success(json.cast<String, dynamic>());
  }

  static String? _validatePeriodEntry(dynamic entry, String dayKey, int index) {
    if (entry is! Map) {
      return 'Entry #${index + 1} in "$dayKey" is not a valid object.';
    }

    const requiredStringFields = ['subject', 'classroom', 'start', 'end'];

    if (!entry.containsKey('period')) {
      return 'Entry #${index + 1} in "$dayKey" is missing the "period" number.';
    }
    final periodVal = entry['period'];
    if (periodVal is! int && int.tryParse(periodVal.toString()) == null) {
      return 'Entry #${index + 1} in "$dayKey" has a non-numeric "period" value.';
    }

    for (final field in requiredStringFields) {
      if (!entry.containsKey(field) || entry[field] == null || entry[field].toString().trim().isEmpty) {
        return 'Entry #${index + 1} in "$dayKey" is missing a valid "$field" value.';
      }
    }

    final timePattern = RegExp(r'^\d{1,2}:\d{2}\s(AM|PM|am|pm)$');
    final start = entry['start'].toString().trim();
    final end = entry['end'].toString().trim();

    if (!timePattern.hasMatch(start)) {
      return 'Entry #${index + 1} in "$dayKey" has an invalid "start" time '
          'format ("$start"). Expected something like "2:00 PM".';
    }
    if (!timePattern.hasMatch(end)) {
      return 'Entry #${index + 1} in "$dayKey" has an invalid "end" time '
          'format ("$end"). Expected something like "2:40 PM".';
    }

    return null;
  }
}
