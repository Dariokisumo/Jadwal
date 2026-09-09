import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  /// Parses strict or relaxed "h:mm a" (e.g. "8:30 AM", "12:10 PM") into minutes from midnight (0..1439).
  static int? parseTimeToMinutes(String timeStr) {
    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(timeStr.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final min = int.tryParse(match.group(2)!);
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (hour == null || min == null) return null;
    if (hour == 12) {
      hour = isPm ? 12 : 0;
    } else if (isPm) {
      hour += 12;
    }
    return hour * 60 + min;
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
  /// Uses a high-density minute-based binary encoding (~80 chars) when possible,
  /// with automatic fallback to JSON base64.
  String toSharePayload() {
    var canUseCompact = true;
    for (final timing in slots.values) {
      if (timing.length < 2 ||
          parseTimeToMinutes(timing[0]) == null ||
          parseTimeToMinutes(timing[1]) == null) {
        canUseCompact = false;
        break;
      }
    }

    if (canUseCompact) {
      final nameBytes = utf8.encode(name);
      final nameLen = nameBytes.length > 255 ? 255 : nameBytes.length;
      final truncatedNameBytes = nameBytes.sublist(0, nameLen);

      final sortedSlots = slots.keys.toList()..sort();
      final slotCount = sortedSlots.length > 255 ? 255 : sortedSlots.length;

      final bytes = BytesBuilder();
      bytes.add([0x4A, 0x50, 0x01]); // Magic 'J', 'P', version 1
      bytes.addByte(nameLen);
      bytes.add(truncatedNameBytes);
      bytes.addByte(slotCount);

      for (var i = 0; i < slotCount; i++) {
        final pNum = sortedSlots[i];
        final startMin = parseTimeToMinutes(slots[pNum]![0])!;
        final endMin = parseTimeToMinutes(slots[pNum]![1])!;

        bytes.addByte(pNum & 0xFF);
        bytes.addByte((startMin >> 8) & 0xFF);
        bytes.addByte(startMin & 0xFF);
        bytes.addByte((endMin >> 8) & 0xFF);
        bytes.addByte(endMin & 0xFF);
      }

      return base64Url.encode(bytes.toBytes()).replaceAll('=', '');
    }

    final jsonStr = jsonEncode(toJson());
    return base64Url.encode(utf8.encode(jsonStr));
  }

  /// Generates a human-friendly text summary with universal web link and import code.
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
    buffer.writeln('https://dariokisumo.github.io/p#$payload');
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
      } else if (cleaned.contains(RegExp(r'https?://'))) {
        final startIdx = cleaned.indexOf(RegExp(r'https?://'));
        final endIdx = cleaned.indexOf(RegExp(r'\s'), startIdx);
        cleaned = endIdx == -1
            ? cleaned.substring(startIdx)
            : cleaned.substring(startIdx, endIdx);
      }

      // Extract from deep link URL: jadwal://profile?data=... or https://...
      if (cleaned.startsWith('jadwal://') ||
          cleaned.startsWith('http://') ||
          cleaned.startsWith('https://')) {
        final uri = Uri.tryParse(cleaned);
        if (uri != null) {
          if (uri.queryParameters.containsKey('data')) {
            cleaned = uri.queryParameters['data']!;
          } else if (uri.hasFragment && uri.fragment.isNotEmpty) {
            cleaned = uri.fragment;
          } else if (uri.pathSegments.isNotEmpty) {
            cleaned = uri.pathSegments.last;
          }
        }
      }

      // Try decoding URL-encoding (e.g. %2B, %2F, %3D) if present
      try {
        cleaned = Uri.decodeComponent(cleaned);
      } catch (_) {}

      // Strip any residual path or hash fragments
      while (cleaned.startsWith('/p/') ||
          cleaned.startsWith('p/') ||
          cleaned.startsWith('p#') ||
          cleaned.startsWith('#')) {
        if (cleaned.startsWith('/p/')) cleaned = cleaned.substring(3);
        if (cleaned.startsWith('p/')) cleaned = cleaned.substring(2);
        if (cleaned.startsWith('p#')) cleaned = cleaned.substring(2);
        if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
      }

      // Extract from code format: JADWAL_PROFILE:...
      if (cleaned.startsWith('JADWAL_PROFILE:')) {
        cleaned = cleaned.substring('JADWAL_PROFILE:'.length).trim();
      }

      // First attempt: base64Url decode
      List<int>? bytes;
      try {
        var normalized = cleaned;
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        bytes = base64Url.decode(normalized);
      } catch (_) {}

      if (bytes != null && bytes.isNotEmpty) {
        var activeBytes = bytes;
        // Optional zlib decompression support
        if (activeBytes.length > 2 && activeBytes[0] == 0x78) {
          try {
            activeBytes = zlib.decode(activeBytes);
          } catch (_) {}
        }

        // Check for compact binary minute-format: 'J', 'P', 0x01
        if (activeBytes.length >= 5 &&
            activeBytes[0] == 0x4A &&
            activeBytes[1] == 0x50 &&
            activeBytes[2] == 0x01) {
          var offset = 3;
          final nameLen = activeBytes[offset++];
          if (activeBytes.length >= offset + nameLen + 1) {
            final name = utf8.decode(activeBytes.sublist(offset, offset + nameLen));
            offset += nameLen;
            final slotCount = activeBytes[offset++];
            if (activeBytes.length >= offset + slotCount * 5) {
              final slots = <int, List<String>>{};
              for (var i = 0; i < slotCount; i++) {
                final pNum = activeBytes[offset++];
                final startMin = (activeBytes[offset++] << 8) | activeBytes[offset++];
                final endMin = (activeBytes[offset++] << 8) | activeBytes[offset++];
                slots[pNum] = [
                  formatMinutesToTime(startMin),
                  formatMinutesToTime(endMin)
                ];
              }
              if (slots.isNotEmpty) {
                return TimingProfile(
                  id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
                  name: name.isEmpty ? 'Schedule' : name,
                  slots: slots,
                );
              }
            }
          }
        }

        // Fallback: UTF-8 JSON
        try {
          final jsonStr = utf8.decode(activeBytes);
          final decodedJson = jsonDecode(jsonStr);
          if (decodedJson is Map<String, dynamic>) {
            final profile = TimingProfile.fromJson(decodedJson);
            if (profile.slots.isNotEmpty) return profile;
          }
        } catch (_) {}
      }

      // Fallback: direct json parse
      try {
        final decodedJson = jsonDecode(cleaned);
        if (decodedJson is Map<String, dynamic>) {
          final profile = TimingProfile.fromJson(decodedJson);
          if (profile.slots.isNotEmpty) return profile;
        }
      } catch (_) {}

      return null;
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
