import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../theme/relational_colors.dart';

enum TimetableImportAction {
  activate,
  saveOnly,
}

/// A relational bottom sheet displayed when a timetable file (.jadwal / .json)
/// is opened in Jadwal from Downloads, WhatsApp, or File Manager.
class TimetableFileImportSheet extends StatelessWidget {
  final Map<String, dynamic> timetableData;
  final String? scheduleName;

  const TimetableFileImportSheet({
    super.key,
    required this.timetableData,
    this.scheduleName,
  });

  /// Displays the timetable file import bottom sheet.
  /// Returns [TimetableImportAction.activate] if user chose to activate now,
  /// [TimetableImportAction.saveOnly] if user chose to add to library only,
  /// or `null` if dismissed.
  static Future<TimetableImportAction?> show(
    BuildContext context, {
    required Map<String, dynamic> timetableData,
    String? scheduleName,
  }) {
    final colors = context.relColors;
    return showModalBottomSheet<TimetableImportAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => TimetableFileImportSheet(
        timetableData: timetableData,
        scheduleName: scheduleName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    final teacher = timetableData['teacher'] as String? ?? 'Teacher';
    final name = scheduleName ?? '$teacher\'s Timetable';
    final timetableMap = timetableData['timetable'] as Map<String, dynamic>? ?? {};

    int totalClasses = 0;
    final List<String> activeDays = [];
    String? firstStart;
    String? lastEnd;

    for (final dayKey in kDayKeys) {
      final periods = timetableMap[dayKey];
      if (periods is List && periods.isNotEmpty) {
        totalClasses += periods.length;
        activeDays.add(dayKey[0].toUpperCase() + dayKey.substring(1, 3));
        for (final p in periods) {
          if (p is Map) {
            firstStart ??= p['start']?.toString();
            lastEnd = p['end']?.toString() ?? lastEnd;
          }
        }
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.md,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            // Badge chip
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderMuted),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 14,
                      color: colors.action,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TIMETABLE FILE OPENED',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colors.action,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Schedule Name & Teacher
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Teacher: $teacher',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.base),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDetailStat(
                        label: 'CLASSES',
                        value: '$totalClasses periods',
                        colors: colors,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: colors.borderSubtle,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      _buildDetailStat(
                        label: 'DAYS',
                        value: '${activeDays.length} days (${activeDays.join(', ')})',
                        colors: colors,
                      ),
                    ],
                  ),
                  if (firstStart != null && lastEnd != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Daily span: $firstStart – $lastEnd',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Primary Action: Activate Now
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, TimetableImportAction.activate);
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Activate Timetable Now',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.action,
                  foregroundColor: colors.onAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Secondary Action: Save to Library
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, TimetableImportAction.saveOnly);
                },
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text(
                  'Save to Library Only',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Dismiss Button
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat({
    required String label,
    required String value,
    required RelationalColors colors,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
