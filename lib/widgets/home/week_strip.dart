import 'package:flutter/material.dart';

import '../../constants/spacing.dart';
import '../../constants/timetable_prompt.dart';
import '../../theme/relational_colors.dart';
import '../day_chip.dart';

/// Week day selector strip — pure UI extracted from HomeScreen.
/// Previously inline LayoutBuilder + Wrap at home_screen.dart:892-929.
class WeekStrip extends StatelessWidget {
  final List<String> daysInOrder;
  final List<DateTime> weekDates;
  final String weekRangeLabel;
  final String selectedDayKey;
  final String todayKey;
  final ValueChanged<String> onDaySelected;

  const WeekStrip({
    super.key,
    required this.daysInOrder,
    required this.weekDates,
    required this.weekRangeLabel,
    required this.selectedDayKey,
    required this.todayKey,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            weekRangeLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = AppSpacing.xs;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final columns = constraints.maxWidth < 320 || textScale > 1.2
                  ? 4
                  : daysInOrder.length;
              final chipWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: List.generate(daysInOrder.length, (index) {
                  final dayKey = daysInOrder[index];
                  return SizedBox(
                    width: chipWidth,
                    child: DayChip(
                      dayKey: dayKey,
                      label: kDayAbbreviations[dayKey] ??
                          dayKey.substring(0, 2),
                      date: weekDates[index],
                      isSelected: dayKey == selectedDayKey,
                      isToday: dayKey == todayKey,
                      isFriday: dayKey == 'friday',
                      onTap: () => onDaySelected(dayKey),
                      colors: colors,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
