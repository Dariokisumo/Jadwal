import 'package:flutter/material.dart';

import '../theme/relational_colors.dart';

/// Centralized feedback utility ensuring consistent, high-contrast,
/// instant notifications across all screens in both Light and Dark modes.
class AppFeedback {
  AppFeedback._();

  /// Displays a success snackbar with a checkmark icon.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFFD4930D),
      duration: duration,
      action: action,
    );
  }

  /// Displays an error or warning snackbar with an alert icon.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFE5484D),
      duration: duration,
      action: action,
    );
  }

  /// Displays an informative snackbar with an info icon.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF8A7E72),
      duration: duration,
      action: action,
    );
  }

  /// Base method to show a high-contrast floating snackbar.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.relColors;

    // High contrast styling:
    // Light mode: Solid dark charcoal background with warm white text
    // Dark mode: Elevated dark surface with subtle border and crisp text
    final bgColor = isDark
        ? colors.surfaceContainerHighest
        : const Color(0xFF1E1C18);
    final fgColor = isDark
        ? colors.textPrimary
        : const Color(0xFFFDFBF7);
    final borderColor = isDark
        ? colors.borderSubtle
        : const Color(0xFF38332B);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: iconColor ?? fgColor,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: fgColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }
}
