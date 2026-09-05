import 'package:flutter/material.dart';

/// Visual identifiers for each period number.
///
/// Odd periods use a circle shape; even periods use a rounded square.
/// Each period gets a distinct Material numeral icon so that period
/// numbers and classroom numbers are never confused at a glance.
class PeriodVisuals {
  PeriodVisuals._();

  static const Map<int, IconData> icons = {
    1: Icons.filter_1,
    2: Icons.filter_2,
    3: Icons.filter_3,
    4: Icons.filter_4,
    5: Icons.filter_5,
    6: Icons.filter_6,
    7: Icons.filter_7,
    8: Icons.filter_8,
    9: Icons.filter_9,
  };

  /// Alternating border radius: odd periods = circle, even = rounded square.
  static BorderRadius borderRadius(int period) {
    return period.isOdd
        ? BorderRadius.circular(18)
        : BorderRadius.circular(10);
  }
}
