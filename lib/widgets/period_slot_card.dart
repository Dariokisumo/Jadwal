import 'package:flutter/material.dart';

import '../theme/relational_colors.dart';
import 'time_picker_helper.dart';

class PeriodSlotCard extends StatelessWidget {
  final int periodNumber;
  final String startTime;
  final String endTime;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final RelationalColors colors;

  const PeriodSlotCard({
    super.key,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.onStartTap,
    required this.onEndTap,
    required this.colors,
  });

  int? _calculateDurationMinutes() {
    final s = parseHmmA(startTime);
    final e = parseHmmA(endTime);
    if (s == null || e == null) return null;
    return e.difference(s).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDurationMinutes();
    final isValid = duration != null && duration > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? colors.borderSubtle : colors.danger.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Period Badge
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.action.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'P$periodNumber',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.action,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Start Time Button
          Expanded(
            flex: 5,
            child: TimePickerChip(
              timeStr: startTime,
              onTap: onStartTap,
              colors: colors,
            ),
          ),

          // Arrow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: colors.textSecondary.withValues(alpha: 0.6),
            ),
          ),

          // End Time Button
          Expanded(
            flex: 5,
            child: TimePickerChip(
              timeStr: endTime,
              onTap: onEndTap,
              colors: colors,
            ),
          ),

          const SizedBox(width: 8),

          // Duration Badge
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isValid
                  ? colors.surfaceContainerHighest
                  : colors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isValid ? '${duration}m' : '!',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isValid ? colors.textSecondary : colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimePickerChip extends StatelessWidget {
  final String timeStr;
  final VoidCallback onTap;
  final RelationalColors colors;

  const TimePickerChip({
    super.key,
    required this.timeStr,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 13, color: colors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  timeStr,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
