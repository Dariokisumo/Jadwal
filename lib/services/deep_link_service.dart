import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/timing_profile.dart';
import 'json_validator.dart';

/// Service responsible for receiving and processing app deep links (e.g. `jadwal://profile?data=...`)
/// and opened timetable files (.jadwal / .json).
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.jadwal/exact_alarm');

  static final StreamController<TimingProfile> _profileStreamController =
      StreamController<TimingProfile>.broadcast();

  static final StreamController<Map<String, dynamic>> _timetableStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<TimingProfile> get onProfileReceived =>
      _profileStreamController.stream;

  static Stream<Map<String, dynamic>> get onTimetableReceived =>
      _timetableStreamController.stream;

  static TimingProfile? _pendingProfile;
  static Map<String, dynamic>? _pendingTimetable;

  /// Returns and consumes any pending profile that arrived before a listener was attached.
  static TimingProfile? consumePendingProfile() {
    final p = _pendingProfile;
    _pendingProfile = null;
    return p;
  }

  /// Returns and consumes any pending timetable that arrived before a listener was attached.
  static Map<String, dynamic>? consumePendingTimetable() {
    final t = _pendingTimetable;
    _pendingTimetable = null;
    return t;
  }

  static bool _initialized = false;

  /// Initializes deep link listener and checks for initial launch deep links / opened files.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final payload = call.arguments?.toString();
        if (payload != null && payload.isNotEmpty) {
          _handleRawPayload(payload);
        }
      }
    });

    // Check cold launch link or file intent
    checkInitialLink();
  }

  /// Checks if the app was launched with a pending deep link or file intent.
  static Future<void> checkInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (link != null && link.isNotEmpty) {
        _handleRawPayload(link);
      }
    } catch (_) {}
  }

  static void _handleRawPayload(String raw) {
    // 1. Check for Timing Profile payload
    final profile = TimingProfile.fromSharePayload(raw);
    if (profile != null) {
      _pendingProfile = profile;
      _profileStreamController.add(profile);
      return;
    }

    // 2. Check for Timetable JSON payload (.jadwal / .json file or shared text)
    final timetable = JsonValidator.tryParseAndNormalize(raw);
    if (timetable != null) {
      _pendingTimetable = timetable;
      _timetableStreamController.add(timetable);
    }
  }

  /// Shares a timetable file via Android's native system share sheet.
  static Future<bool> shareTimetableFile({
    required String fileName,
    required String content,
    String title = 'Share Timetable',
  }) async {
    try {
      if (!Platform.isAndroid) return false;

      final success = await _channel.invokeMethod<bool>('shareFile', {
        'fileName': fileName,
        'content': content,
        'title': title,
      });
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Saves a timetable file to Android's public Downloads directory.
  /// Returns the saved file path, or null if failed.
  static Future<String?> saveTimetableFileToDownloads({
    required String fileName,
    required String content,
  }) async {
    try {
      if (!Platform.isAndroid) return null;
      final path = await _channel.invokeMethod<String>('saveFileToDownloads', {
        'fileName': fileName,
        'content': content,
      });
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Checks whether an Android app with [packageName] is installed on this device.
  static Future<bool> isAppInstalled(String packageName) async {
    try {
      if (!Platform.isAndroid) return false;
      final installed = await _channel.invokeMethod<bool>('isAppInstalled', {
        'package': packageName,
      });
      return installed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches an app via [packageName] if installed, or falls back to [fallbackUrl].
  static Future<bool> launchAppOrUrl({
    String? packageName,
    required String fallbackUrl,
  }) async {
    try {
      if (!Platform.isAndroid) return false;
      final launched = await _channel.invokeMethod<bool>('launchAppOrUrl', {
        if (packageName != null) 'package': packageName,
        'url': fallbackUrl,
      });
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }
}
