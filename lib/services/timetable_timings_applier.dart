import 'dart:async';

import '../models/timing_profile.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'widget_data_service.dart';

/// Service responsible for applying timing profile start/end times across all
/// matching period slots in the active timetable.
abstract final class TimetableTimingsApplier {
  /// Updates start/end times in [timetableData] using slot definitions from [profile],
  /// persists the changes to [StorageService], and asynchronously updates widgets and notifications.
  ///
  /// Returns the updated timetable data map, or `null` if the input timetable was invalid.
  static Future<Map<String, dynamic>?> applyProfile({
    required TimingProfile profile,
    required List<TimingProfile> allProfiles,
  }) async {
    final timetableData = await StorageService.loadTimetable();
    if (timetableData == null || timetableData['timetable'] is! Map) {
      return null;
    }

    final rawDays = timetableData['timetable'] as Map;
    final updatedDays = <String, dynamic>{};

    for (final entry in rawDays.entries) {
      final dayKey = entry.key;
      final periodList = entry.value;
      if (periodList is List) {
        final updatedList = <Map<String, dynamic>>[];
        for (final item in periodList) {
          if (item is Map) {
            final periodMap = Map<String, dynamic>.from(item);
            final pNum = periodMap['period'] is int
                ? periodMap['period'] as int
                : int.tryParse(periodMap['period'].toString());

            if (pNum != null) {
              final times = profile.getTimingFor(pNum);
              periodMap['start'] = times[0];
              periodMap['end'] = times[1];
            }
            updatedList.add(periodMap);
          }
        }
        updatedDays[dayKey] = updatedList;
      } else {
        updatedDays[dayKey] = periodList;
      }
    }

    timetableData['timetable'] = updatedDays;

    await StorageService.saveTimetable(timetableData);
    await StorageService.saveActiveProfileId(profile.id);
    await StorageService.saveTimingProfiles(allProfiles);

    // Update notifications and home widget in background
    unawaited(NotificationService.scheduleAll(updatedDays));
    unawaited(WidgetDataService.updateWidget());

    return timetableData;
  }
}
