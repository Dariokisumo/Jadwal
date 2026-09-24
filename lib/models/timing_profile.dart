import '../constants/period_schedule.dart';
import '../services/timing_profile_codec.dart';

/// A named timing profile (e.g. "Standard Schedule", "Winter Timing", "Exam Schedule").
/// Holds the start and end times for each period slot (1..N).
class TimingProfile {
  final String id;
  String name;
  Map<int, List<String>> slots; // periodNumber -> [start, end]

  TimingProfile({
    required this.id,
    required this.name,
    required this.slots,
  });

  /// Returns [start, end] for [periodNumber].
  List<String> getTimingFor(int periodNumber) {
    if (slots.containsKey(periodNumber) && slots[periodNumber]!.length >= 2) {
      return slots[periodNumber]!;
    }
    return defaultTimingForPeriod(periodNumber);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slots': slots.map((k, v) => MapEntry(k.toString(), v)),
      };

  /// Parses 12-hour ("2:00 PM", "2:00PM") and 24-hour ("14:00") into minutes
  /// from midnight (0..1439). Canonical parser shared with [JsonValidator].
  /// Returns null if unrecognized. Strict: 12h hour 1-12, 24h hour 0-23, min 0-59.
  static int? parseTimeToMinutes(String timeStr) {
    final s = timeStr.trim();
    if (s.isEmpty) return null;
    final m12 =
        RegExp(r'^0?(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
            .firstMatch(s);
    if (m12 != null) {
      final hour = int.tryParse(m12.group(1)!);
      final min = int.tryParse(m12.group(2)!);
      if (hour == null || hour < 1 || hour > 12) return null;
      if (min == null || min < 0 || min > 59) return null;
      final isPm = m12.group(3)!.toUpperCase() == 'PM';
      return (hour % 12 + (isPm ? 12 : 0)) * 60 + min;
    }
    final m24 = RegExp(r'^0?(\d{1,2}):(\d{2})$').firstMatch(s);
    if (m24 != null) {
      final h24 = int.tryParse(m24.group(1)!);
      final min = int.tryParse(m24.group(2)!);
      if (h24 == null || h24 < 0 || h24 > 23) return null;
      if (min == null || min < 0 || min > 59) return null;
      return h24 * 60 + min;
    }
    return null;
  }

  /// Converts minutes from midnight (0..1439) into formatted "h:mm a" string.
  static String formatMinutesToTime(int totalMin) {
    var h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$hour12:$mStr $period';
  }

  /// Serializes this profile into a compact URL-safe base64 string.
  /// Delegates to [TimingProfileCodec.encode].
  String toSharePayload() => TimingProfileCodec.encode(this);

  /// Generates a human-friendly text summary with universal web link and import code.
  /// Delegates to [TimingProfileCodec.formatShareText].
  String toFormattedShareText() => TimingProfileCodec.formatShareText(this);

  /// Shares this profile via Android's native system share sheet.
  /// Delegates to [TimingProfileCodec.share].
  static Future<void> share(TimingProfile profile) =>
      TimingProfileCodec.share(profile);

  /// Parses a share payload, deep link URI, or raw JSON into a validated [TimingProfile].
  /// Delegates to [TimingProfileCodec.decode].
  static TimingProfile? fromSharePayload(String raw) =>
      TimingProfileCodec.decode(raw);

  factory TimingProfile.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as Map<String, dynamic>? ?? {};
    final slots = <int, List<String>>{};
    rawSlots.forEach((k, v) {
      final pNum = int.tryParse(k);
      if (pNum != null && v is List) {
        slots[pNum] = v.map((e) => e.toString()).toList();
      }
    });
    return TimingProfile(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Schedule',
      slots: slots,
    );
  }

  TimingProfile copyWith({
    String? id,
    String? name,
    Map<int, List<String>>? slots,
  }) {
    return TimingProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      slots: slots ??
          Map<int, List<String>>.from(
            this.slots.map((k, v) => MapEntry(k, List<String>.from(v))),
          ),
    );
  }

  /// Create a default profile based on given period count or existing timetable.
  factory TimingProfile.defaultProfile({
    int periodCount = 9,
    Map<String, dynamic>? timetable,
  }) {
    final slots = <int, List<String>>{};

    // First, try extracting timings from existing timetable
    if (timetable != null && timetable['timetable'] is Map) {
      final days = timetable['timetable'] as Map;
      for (final dayList in days.values) {
        if (dayList is List) {
          for (final item in dayList) {
            if (item is Map) {
              final pNum = item['period'] is int
                  ? item['period'] as int
                  : int.tryParse(item['period'].toString());
              final start = item['start']?.toString();
              final end = item['end']?.toString();
              if (pNum != null &&
                  start != null &&
                  end != null &&
                  !slots.containsKey(pNum)) {
                slots[pNum] = [start, end];
              }
            }
          }
        }
      }
    }

    // Fill in any remaining slots up to periodCount
    for (var i = 1; i <= periodCount; i++) {
      if (!slots.containsKey(i)) {
        slots[i] = defaultTimingForPeriod(i);
      }
    }

    return TimingProfile(
      id: 'default',
      name: 'Standard Schedule',
      slots: slots,
    );
  }
}
