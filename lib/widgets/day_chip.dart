import 'package:flutter/material.dart';

import '../constants/spacing.dart';
import '../theme/relational_colors.dart';

class DayChip extends StatelessWidget {
  final String dayKey;
  final String label;
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isFriday;
  final VoidCallback onTap;
  final RelationalColors colors;

  const DayChip({
    super.key,
    required this.dayKey,
    required this.label,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isFriday,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chipColor = isFriday || isSelected
        ? colors.actionSubtle
        : isToday
            ? colors.surface
            : colors.surfaceContainerHighest;
    final textColor = isFriday ? colors.textSecondary : colors.textPrimary;
    final borderColor = isSelected || isToday
        ? colors.action
        : isFriday
            ? colors.borderMuted
            : colors.borderSubtle;
    final fullDate = MaterialLocalizations.of(context).formatFullDate(date);
    final states = <String>[
      if (isToday) 'today',
      if (isSelected) 'selected',
      if (isFriday) 'rest day',
    ].join(', ');
    final semanticsLabel = states.isEmpty ? fullDate : '$fullDate, $states';
    final borderRadius = BorderRadius.circular(12);

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: !isFriday,
      selected: isSelected,
      onTap: isFriday ? null : onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: borderColor,
            width: isSelected || isToday ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isFriday ? null : onTap,
            focusColor: colors.actionSubtle,
            hoverColor: colors.actionSubtle,
            splashColor: colors.actionSubtle,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppSpacing.sm,
                    height: AppSpacing.sm,
                    child: isToday
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.action,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
