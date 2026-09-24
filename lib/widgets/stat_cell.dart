import 'package:flutter/material.dart';

import '../theme/relational_colors.dart';

/// Shared label/value stat cell (ponytail: single copy for summary/detail).
class StatCell extends StatelessWidget {
  final String label;
  final String value;
  final RelationalColors colors;
  final double labelSize;
  final FontWeight labelWeight;
  final bool uppercase;

  const StatCell({
    super.key,
    required this.label,
    required this.value,
    required this.colors,
    this.labelSize = 11,
    this.labelWeight = FontWeight.w600,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uppercase ? label.toUpperCase() : label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: labelSize,
              fontWeight: labelWeight,
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
