import 'package:flutter/material.dart';

import '../../constants/spacing.dart';
import '../../theme/relational_colors.dart';
import '../break_indicator.dart';
import '../period_slot_card.dart';

/// Bell-schedule slots list — pure UI extracted from
/// PeriodTimingsScreen._buildSlotsList. Break labels derived inline.
class SlotsList extends StatelessWidget {
  final int periodCount;
  final List<String> Function(int periodNumber) timingFor;
  final int? Function(String endPrev, String startNext) gapMinutes;
  final void Function({required int periodNumber, required bool isStart})
      onPickTime;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const SlotsList({
    super.key,
    required this.periodCount,
    required this.timingFor,
    required this.gapMinutes,
    required this.onPickTime,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    final slots = <Widget>[];

    for (var i = 1; i <= periodCount; i++) {
      final times = timingFor(i);
      final startTime = times[0];
      final endTime = times[1];

      if (i > 1) {
        final prevTimes = timingFor(i - 1);
        final gap = gapMinutes(prevTimes[1], startTime);
        if (gap != null && gap > 0) {
          final String label;
          if (gap >= 35) {
            label = 'Lunch • ${gap}m';
          } else if (gap >= 15) {
            label = 'Recess • ${gap}m';
          } else {
            label = 'Break • ${gap}m';
          }
          slots.add(BreakIndicator(label: label, gapMinutes: gap));
        }
      }

      slots.add(
        PeriodSlotCard(
          periodNumber: i,
          startTime: startTime,
          endTime: endTime,
          onStartTap: () =>
              onPickTime(periodNumber: i, isStart: true),
          onEndTap: () =>
              onPickTime(periodNumber: i, isStart: false),
          colors: colors,
        ),
      );
    }

    slots.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add Period ${periodCount + 1}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.action,
                side: BorderSide(color: colors.action.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (periodCount > 1)
              TextButton.icon(
                onPressed: onRemove,
                icon: Icon(Icons.remove_rounded,
                    size: 18, color: colors.danger),
                label: Text(
                  'Remove Period $periodCount',
                  style:
                      TextStyle(color: colors.danger, fontFamily: 'Geist'),
                ),
              ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: slots,
    );
  }
}
