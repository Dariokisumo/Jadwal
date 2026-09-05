import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_version.dart';

/// Structured information about a GitHub release.
class AppReleaseInfo {
  final String tagName;
  final String releaseName;
  final List<String> changelogBullets;
  final String htmlUrl;
  final String? arm64Url;
  final String? arm32Url;
  final String? fallbackApkUrl;
  final bool isNewer;

  const AppReleaseInfo({
    required this.tagName,
    required this.releaseName,
    required this.changelogBullets,
    required this.htmlUrl,
    this.arm64Url,
    this.arm32Url,
    this.fallbackApkUrl,
    required this.isNewer,
  });

  /// The best primary download URL available (prefers arm64 for modern Android).
  String get primaryDownloadUrl => arm64Url ?? fallbackApkUrl ?? htmlUrl;

  /// Returns the appropriate APK download URL matching the detected device architecture.
  String getDownloadUrlForArch(String arch) {
    if (arch == 'arm32') {
      return arm32Url ?? primaryDownloadUrl;
    }
    return arm64Url ?? primaryDownloadUrl;
  }
}

/// Lightweight, offline-resilient GitHub release update checker.
class UpdateService {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/Dariokisumo/Jadwal/releases/latest';
  static const String _lastCheckKey = 'last_github_update_check_time';
  static const Duration _checkCooldown = Duration(hours: 24);

  /// Checks GitHub for the latest release.
  ///
  /// If [force] is false (e.g. on app launch), this only queries GitHub if at
  /// least 24 hours have passed since the last check.
  ///
  /// Returns [AppReleaseInfo] if a release was fetched successfully, or `null`
  /// if offline, rate-limited, timed out, or within the cooldown period.
  static Future<AppReleaseInfo?> checkForUpdate({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final lastCheckMs = prefs.getInt(_lastCheckKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastCheckMs < _checkCooldown.inMilliseconds) {
        return null;
      }
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse(_releasesApiUrl));
      request.headers.set('User-Agent', 'Jadwal-Android-App');
      request.headers.set('Accept', 'application/vnd.github+json');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(body);

      // Record successful check time
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      final tagName = (data['tag_name'] as String? ?? '').trim();
      final releaseName = (data['name'] as String? ?? tagName).trim();
      final rawBody = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ??
          'https://github.com/Dariokisumo/Jadwal/releases';

      // Parse asset download links
      String? arm64Url;
      String? arm32Url;
      String? fallbackApkUrl;

      final assets = data['assets'] as List? ?? [];
      for (final item in assets) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final downloadUrl = item['browser_download_url'] as String?;

          if (downloadUrl != null && name.endsWith('.apk')) {
            if (name.contains('arm64') || name.contains('v8a')) {
              arm64Url = downloadUrl;
            } else if (name.contains('arm32') ||
                name.contains('v7a') ||
                name.contains('armeabi')) {
              arm32Url = downloadUrl;
            } else {
              fallbackApkUrl ??= downloadUrl;
            }
          }
        }
      }

      final isNewer = isVersionNewer(tagName, kAppVersion);
      final changelogBullets = parseChangelogToSimpleEnglish(rawBody);

      return AppReleaseInfo(
        tagName: tagName,
        releaseName: releaseName,
        changelogBullets: changelogBullets,
        htmlUrl: htmlUrl,
        arm64Url: arm64Url,
        arm32Url: arm32Url,
        fallbackApkUrl: fallbackApkUrl,
        isNewer: isNewer,
      );
    } catch (_) {
      // Offline, network failure, or timeout — fails silently.
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Compares semantic versions (e.g. 'v2.1.0' vs '2.0.0').
  /// Returns true if [remoteTag] is strictly newer than [currentVersion].
  static bool isVersionNewer(String remoteTag, String currentVersion) {
    try {
      final cleanRemote = remoteTag.replaceAll(RegExp(r'^[vV]'), '').split('-')[0];
      final cleanLocal = currentVersion.replaceAll(RegExp(r'^[vV]'), '').split('+')[0];

      final remoteParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final localParts = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }
      while (localParts.length < 3) {
        localParts.add(0);
      }

      for (var i = 0; i < 3; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Parses raw release markdown into a concise, plain English list of highlights.
  static List<String> parseChangelogToSimpleEnglish(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return const [
        'New improvements and optimizations for a smoother experience.',
        'General bug fixes and stability enhancements.',
      ];
    }

    final lines = rawBody.split('\n');
    final bullets = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();

      // Skip empty lines, headers, tables, code blocks, or metadata lines
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith('|') ||
          trimmed.startsWith('```') ||
          trimmed.startsWith('---') ||
          trimmed.toLowerCase().contains('downloads & architecture') ||
          trimmed.toLowerCase().contains('verification & hashes')) {
        continue;
      }

      // Check for bullet items: "- ", "* ", "1. "
      final bulletMatch = RegExp(r'^(?:[-*]|\d+\.)\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        var content = bulletMatch.group(1) ?? '';
        // Clean markdown bold/italic (**bold** -> bold)
        content = content.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
        content = content.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
        content = content.replaceAll(RegExp(r'`([^`]+)`'), r'$1');

        if (content.isNotEmpty && bullets.length < 5) {
          bullets.add(content);
        }
      }
    }

    if (bullets.isEmpty) {
      return const [
        'New improvements and optimizations for a smoother experience.',
        'General bug fixes and stability enhancements.',
      ];
    }

    return bullets;
  }

  static const _platform = MethodChannel('com.jadwal/exact_alarm');

  /// Detects whether the current device's hardware/OS supports 64-bit ('arm64')
  /// or only 32-bit ('arm32').
  static Future<String> getDeviceArchitecture() async {
    try {
      if (Platform.isAndroid) {
        final arch = await _platform.invokeMethod<String>('getDeviceArchitecture');
        if (arch != null && arch.isNotEmpty) {
          return arch;
        }
      }
    } catch (_) {}
    return 'arm64'; // Default to modern 64-bit architecture
  }

  /// Opens a URL using Android's action_view intent to trigger browser download
  /// or open the GitHub release page.
  static Future<bool> openUrl(String url) async {
    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
        );
        await intent.launch();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
