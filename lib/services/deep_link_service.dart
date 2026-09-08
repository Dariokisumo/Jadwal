import 'dart:async';
import 'package:flutter/services.dart';
import '../models/timing_profile.dart';

/// Service responsible for receiving and processing app deep links (e.g. `jadwal://profile?data=...`).
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.jadwal/exact_alarm');
  static final StreamController<TimingProfile> _profileStreamController =
      StreamController<TimingProfile>.broadcast();

  static Stream<TimingProfile> get onProfileReceived =>
      _profileStreamController.stream;

  static bool _initialized = false;

  /// Initializes deep link listener and checks for initial launch deep links.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments?.toString();
        if (link != null && link.isNotEmpty) {
          _handleRawPayload(link);
        }
      }
    });

    // Check cold launch link
    checkInitialLink();
  }

  /// Checks if the app was launched with a pending deep link intent.
  static Future<void> checkInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (link != null && link.isNotEmpty) {
        _handleRawPayload(link);
      }
    } catch (_) {}
  }

  static void _handleRawPayload(String raw) {
    final profile = TimingProfile.fromSharePayload(raw);
    if (profile != null) {
      _profileStreamController.add(profile);
    }
  }
}
