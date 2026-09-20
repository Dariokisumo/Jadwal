import 'package:flutter/material.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../theme/relational_colors.dart';
import 'day_chip.dart';

/// Top horizontal selector displaying day chips (Saturday through Friday)
/// with today indicators and rest day handling.
class HomeDaySelector extends StatelessWidget {
  final List<String> allDays;
  final String selectedDayKey;
  final String todayKey;
  final ValueChanged<String> onDaySelected;
  final RelationalColors colors;

  const HomeDaySelector({
    super.key,
    required this.allDays,
    required this.selectedDayKey,
    required this.todayKey,
    required this.onDaySelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.borderSubtle,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: allDays.map((dayKey) {
          return DayChip(
            dayKey: dayKey,
            label: kDayAbbreviations[dayKey] ?? dayKey.substring(0, 2),
            isSelected: dayKey == selectedDayKey,
            isToday: dayKey == todayKey,
            isFriday: dayKey == 'friday',
            onTap: () => onDaySelected(dayKey),
            colors: colors,
          );
        }).toList(),
      ),
    );
  }
}
