import 'package:flutter/material.dart';

import '../constants/timetable_prompt.dart';
import '../theme/relational_colors.dart';

class DayChip extends StatelessWidget {
  final String dayKey;
  final String label;
  final bool isSelected;
  final bool isToday;
  final bool isFriday;
  final VoidCallback onTap;
  final RelationalColors colors;

  const DayChip({
    super.key,
    required this.dayKey,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.isFriday,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = isFriday
        ? colors.actionSubtle
        : isSelected
            ? colors.action
            : isToday
                ? colors.surface
                : colors.surfaceContainerHighest;

    final textColor = isFriday
        ? colors.action.withValues(alpha: 0.6)
        : isSelected
            ? colors.onAction
            : colors.textPrimary;

    final borderColor = isFriday
        ? colors.action.withValues(alpha: 0.2)
        : isSelected
            ? colors.action
            : isToday
                ? colors.action
                : colors.borderSubtle;

    final dayLabel = kDayLabels[dayKey] ?? dayKey;
    final semanticsLabel = isFriday
        ? '$dayLabel, no classes'
        : '$dayLabel${isToday ? ', today' : ''}${isSelected ? ', selected' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: !isFriday,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isFriday ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || isToday ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: isFriday
                    ? Icon(
                        Icons.coffee_rounded,
                        size: 16,
                        color: textColor,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              if (isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: CustomPaint(
                    size: const Size(8, 5),
                    painter: TrianglePainter(color: colors.action),
                  ),
                )
              else
                const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  const TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrianglePainter old) => old.color != color;
}
