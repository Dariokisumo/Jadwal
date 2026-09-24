import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import '../models/timing_profile.dart';

/// Dedicated codec and wire protocol handler for [TimingProfile].
///
/// Encapsulates URL-safe base64, minute-based binary encoding (~80 chars),
/// zlib decompression, and Android platform sharing.
abstract final class TimingProfileCodec {
  /// Serializes a [TimingProfile] into a compact URL-safe base64 string.
  /// Uses a high-density minute-based binary encoding (~80 chars) when possible,
  /// with automatic fallback to JSON base64.
  static String encode(TimingProfile profile) {
    var canUseCompact = true;
    for (final timing in profile.slots.values) {
      if (timing.length < 2 ||
          TimingProfile.parseTimeToMinutes(timing[0]) == null ||
          TimingProfile.parseTimeToMinutes(timing[1]) == null) {
        canUseCompact = false;
        break;
      }
    }

    if (canUseCompact) {
      final nameBytes = utf8.encode(profile.name);
      final nameLen = nameBytes.length > 255 ? 255 : nameBytes.length;
      final truncatedNameBytes = nameBytes.sublist(0, nameLen);

      final sortedSlots = profile.slots.keys.toList()..sort();
      final slotCount = sortedSlots.length > 255 ? 255 : sortedSlots.length;

      final bytes = BytesBuilder();
      bytes.add([0x4A, 0x50, 0x01]); // Magic 'J', 'P', version 1
      bytes.addByte(nameLen);
      bytes.add(truncatedNameBytes);
      bytes.addByte(slotCount);

      for (var i = 0; i < slotCount; i++) {
        final pNum = sortedSlots[i];
        final startMin = TimingProfile.parseTimeToMinutes(profile.slots[pNum]![0])!;
        final endMin = TimingProfile.parseTimeToMinutes(profile.slots[pNum]![1])!;

        bytes.addByte(pNum & 0xFF);
        bytes.addByte((startMin >> 8) & 0xFF);
        bytes.addByte(startMin & 0xFF);
        bytes.addByte((endMin >> 8) & 0xFF);
        bytes.addByte(endMin & 0xFF);
      }

      return base64Url.encode(bytes.toBytes()).replaceAll('=', '');
    }

    final jsonStr = jsonEncode(profile.toJson());
    return base64Url.encode(utf8.encode(jsonStr));
  }

  /// Generates a human-friendly text summary with universal web link and import code.
  static String formatShareText(TimingProfile profile) {
    final payload = encode(profile);
    final sortedSlots = profile.slots.keys.toList()..sort();
    final count = sortedSlots.length;

    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal Timing Profile: "${profile.name}" ($count periods)\n');

    for (final p in sortedSlots) {
      final t = profile.slots[p]!;
      buffer.writeln('• Period $p: ${t[0]} – ${t[1]}');
    }

    buffer.writeln('\nOpen in Jadwal:');
    buffer.writeln('https://dariokisumo.github.io/p#$payload');
    buffer.writeln('\nOr import code in Jadwal (Misc > Period Timings):');
    buffer.writeln('JADWAL_PROFILE:$payload');

    return buffer.toString();
  }

  /// Shares a profile via Android's native system share sheet.
  static Future<void> share(TimingProfile profile) async {
    try {
      const channel = MethodChannel('com.jadwal/exact_alarm');
      await channel.invokeMethod<bool>('shareText', {
        'text': formatShareText(profile),
        'title': 'Share Timing Profile',
      });
    } catch (_) {}
  }

  // ponytail: single helper preserving the original marker priority
  // (jadwal:// > JADWAL_PROFILE: > https?://); each slices marker → whitespace.
  static String _extractToken(String s) {
    String slice(String marker) {
      final start = s.indexOf(marker);
      if (start == -1) return s;
      final end = s.indexOf(RegExp(r'\s'), start);
      return end == -1 ? s.substring(start) : s.substring(start, end);
    }

    if (s.contains('jadwal://profile?data=')) {
      return slice('jadwal://profile?data=');
    }
    if (s.contains('JADWAL_PROFILE:')) return slice('JADWAL_PROFILE:');
    final m = RegExp(r'https?://').firstMatch(s);
    if (m != null) {
      final end = s.indexOf(RegExp(r'\s'), m.start);
      return end == -1 ? s.substring(m.start) : s.substring(m.start, end);
    }
    return s;
  }

  /// Parses a share payload, deep link URI, or raw JSON into a validated [TimingProfile].
  static TimingProfile? decode(String raw) {
    try {
      var cleaned = _extractToken(raw.trim());

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

      // Strip any residual path or hash fragments (ponytail: single RegExp ≡ while loop).
      cleaned = cleaned.replaceFirst(RegExp(r'^(?:/p/|p/|p#|#)+'), '');

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
                  TimingProfile.formatMinutesToTime(startMin),
                  TimingProfile.formatMinutesToTime(endMin)
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
}
