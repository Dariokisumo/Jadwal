import 'package:flutter/material.dart';

/// Visual identifiers for each period number.
///
/// Odd periods use a circle shape; even periods use a rounded square.
/// Each period gets a distinct Material numeral icon so that period
/// numbers and classroom numbers are never confused at a glance.
class PeriodVisuals {
  PeriodVisuals._();

  /// Consistent rounded rectangle token for period numeral badges.
  static BorderRadius borderRadius([int? period]) {
    return BorderRadius.circular(10);
  }
}
