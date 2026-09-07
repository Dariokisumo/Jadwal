import '../constants/period_schedule.dart';

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
