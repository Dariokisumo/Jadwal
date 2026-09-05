import 'package:intl/intl.dart';

/// Status of a period relative to the current moment.
enum PeriodStatus { upcoming, active, finished }

class Period {
  final int periodNumber;
  final String subject;
  final String classroom;
  final String start; // e.g. "2:00 PM"
  final String end; // e.g. "2:40 PM"

  Period({
    required this.periodNumber,
    required this.subject,
    required this.classroom,
    required this.start,
    required this.end,
  });

  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      periodNumber: json['period'] is int
          ? json['period'] as int
          : int.parse(json['period'].toString()),
      subject: json['subject'].toString(),
      classroom: json['classroom'].toString(),
      start: json['start'].toString(),
      end: json['end'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'period': periodNumber,
        'subject': subject,
        'classroom': classroom,
        'start': start,
        'end': end,
      };

  /// Parses a "h:mm a" string (e.g. "2:00 PM") into today's DateTime.
  /// Returns null if parsing fails rather than throwing, so a single
  /// malformed entry never crashes the whole list.
  static DateTime? _parseTimeToday(String timeStr) {
    try {
      final now = DateTime.now();
      final format = DateFormat('h:mm a');
      final parsed = format.parse(timeStr.trim());
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  DateTime? get startTime => _parseTimeToday(start);
  DateTime? get endTime => _parseTimeToday(end);

  /// Current status of this period. If times fail to parse, defaults
  /// to `upcoming` so the period is still visible rather than hidden.
  PeriodStatus get status {
    final s = startTime;
    final e = endTime;
    if (s == null || e == null) return PeriodStatus.upcoming;

    final now = DateTime.now();
    if (now.isBefore(s)) return PeriodStatus.upcoming;
    if (now.isAfter(e)) return PeriodStatus.finished;
    return PeriodStatus.active;
  }

  /// Progress through this period as a 0.0–1.0 value.
  /// Returns null if the period is not currently active.
  double? get progress {
    final s = startTime;
    final e = endTime;
    if (s == null || e == null) return null;
    final now = DateTime.now();
    if (now.isBefore(s) || now.isAfter(e)) return null;
    final total = e.difference(s).inSeconds;
    if (total <= 0) return null;
    final elapsed = now.difference(s).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Minutes until this period starts. Returns null if not upcoming.
  int? get minutesUntilStart {
    final s = startTime;
    if (s == null) return null;
    final now = DateTime.now();
    if (now.isAfter(s)) return null;
    return s.difference(now).inMinutes;
  }

  /// Formats total minutes into a human-readable string.
  /// e.g. 65 -> "1h 5m", 45 -> "45m", 1 -> "1m"
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes >= 60) {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${totalMinutes}m';
  }
}
