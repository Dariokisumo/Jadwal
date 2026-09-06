import 'package:flutter/material.dart';

import '../theme/relational_colors.dart';

/// A subtle, restrained break pill connector between timetable periods.
///
/// Displays the duration and break type (e.g. "15m Recess", "1h 5m Lunch Break").
/// When [isNow] is true, gently highlights with active accent tint and indicator dot.
class BreakIndicator extends StatelessWidget {
  final String label;
  final int gapMinutes;
  final bool isNow;

  const BreakIndicator({
    super.key,
    required this.label,
    required this.gapMinutes,
    this.isNow = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    final pillBg = isNow ? colors.actionSubtle : colors.surfaceContainer;
    final pillBorder = isNow ? colors.action.withValues(alpha: 0.35) : colors.borderSubtle;
    final contentColor = isNow ? colors.action : colors.textSecondary;
    final isLunch = label.toLowerCase().contains('lunch');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        label: isNow ? 'Currently on break: $label' : 'Scheduled break: $label',
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isNow
                    ? colors.action.withValues(alpha: 0.3)
                    : colors.borderSubtle.withValues(alpha: 0.6),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pillBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLunch ? Icons.restaurant_outlined : Icons.coffee_rounded,
                    size: 12,
                    color: contentColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isNow ? 'NOW • $label' : label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: isNow ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.2,
                      color: contentColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isNow
                    ? colors.action.withValues(alpha: 0.3)
                    : colors.borderSubtle.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
