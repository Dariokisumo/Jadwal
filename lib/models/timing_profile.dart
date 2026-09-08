import 'dart:convert';
import 'package:flutter/services.dart';

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

  /// Serializes this profile into a URL-safe base64 string.
  String toSharePayload() {
    final jsonStr = jsonEncode(toJson());
    return base64Url.encode(utf8.encode(jsonStr));
  }

  /// Generates a human-friendly text summary with deep link and import code.
  String toFormattedShareText() {
    final payload = toSharePayload();
    final sortedSlots = slots.keys.toList()..sort();
    final count = sortedSlots.length;

    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal Timing Profile: "$name" ($count periods)\n');

    for (final p in sortedSlots) {
      final t = slots[p]!;
      buffer.writeln('• Period $p: ${t[0]} – ${t[1]}');
    }

    buffer.writeln('\nOpen in Jadwal:');
    buffer.writeln('jadwal://profile?data=$payload');
    buffer.writeln('\nOr import code in Jadwal (Misc > Period Timings):');
    buffer.writeln('JADWAL_PROFILE:$payload');

    return buffer.toString();
  }

  /// Shares this profile via Android's native system share sheet.
  static Future<void> share(TimingProfile profile) async {
    try {
      const channel = MethodChannel('com.jadwal/exact_alarm');
      await channel.invokeMethod<bool>('shareText', {
        'text': profile.toFormattedShareText(),
        'title': 'Share Timing Profile',
      });
    } catch (_) {}
  }

  /// Parses a share payload, deep link URI, or raw JSON into a validated [TimingProfile].
  static TimingProfile? fromSharePayload(String raw) {
    try {
      var cleaned = raw.trim();

      // Extract substring if user pasted an entire message with multiple lines
      if (cleaned.contains('jadwal://profile?data=')) {
        final startIdx = cleaned.indexOf('jadwal://profile?data=');
        final endIdx = cleaned.indexOf(RegExp(r'\s'), startIdx);
        cleaned = endIdx == -1
            ? cleaned.substring(startIdx)
            : cleaned.substring(startIdx, endIdx);
      } else if (cleaned.contains('JADWAL_PROFILE:')) {
        final startIdx = cleaned.indexOf('JADWAL_PROFILE:');
        final endIdx = cleaned.indexOf(RegExp(r'\s'), startIdx);
        cleaned = endIdx == -1
            ? cleaned.substring(startIdx)
            : cleaned.substring(startIdx, endIdx);
      }

      // Extract from deep link URL: jadwal://profile?data=...
      if (cleaned.startsWith('jadwal://')) {
        final uri = Uri.tryParse(cleaned);
        if (uri != null && uri.queryParameters.containsKey('data')) {
          cleaned = uri.queryParameters['data']!;
        }
      }

      // Extract from code format: JADWAL_PROFILE:...
      if (cleaned.startsWith('JADWAL_PROFILE:')) {
        cleaned = cleaned.substring('JADWAL_PROFILE:'.length).trim();
      }

      // First attempt: base64Url decode
      Map<String, dynamic>? decodedJson;
      try {
        // Normalize base64 if needed
        var normalized = cleaned;
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final bytes = base64Url.decode(normalized);
        final jsonStr = utf8.decode(bytes);
        decodedJson = jsonDecode(jsonStr) as Map<String, dynamic>?;
      } catch (_) {
        // Fallback: direct json parse
        try {
          decodedJson = jsonDecode(cleaned) as Map<String, dynamic>?;
        } catch (_) {}
      }

      if (decodedJson == null) return null;

      final profile = TimingProfile.fromJson(decodedJson);
      if (profile.slots.isEmpty) return null;

      return profile;
    } catch (_) {
      return null;
    }
  }

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
