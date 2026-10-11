import 'package:flutter/material.dart';

import '../theme/relational_colors.dart';

/// Canonical confirm dialog — single source for the AlertDialog scaffold
/// previously copy-pasted across 10 call sites.
class AppDialog {
  AppDialog._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool danger = true,
  }) {
    final colors = context.relColors;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Geist',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          body,
          style: TextStyle(
            fontFamily: 'Geist',
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelLabel,
              style: const TextStyle(fontFamily: 'Geist'),
            ),
          ),
          if (danger)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
