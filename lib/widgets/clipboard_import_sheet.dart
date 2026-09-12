import 'package:flutter/material.dart';

import '../constants/spacing.dart';
import '../theme/relational_colors.dart';

/// A calm, non-intrusive bottom sheet prompting the user to import
/// a timing profile or timetable detected on their clipboard.
class ClipboardImportSheet extends StatelessWidget {
  final String title;
  final String badge;
  final String name;
  final String details;
  final String confirmLabel;
  final IconData icon;

  const ClipboardImportSheet({
    super.key,
    required this.title,
    required this.badge,
    required this.name,
    required this.details,
    required this.confirmLabel,
    required this.icon,
  });

  /// Displays the clipboard import bottom sheet.
  /// Returns `true` if user tapped import/confirm,
  /// `false` if user explicitly dismissed, or `null` if tapped outside.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String badge,
    required String name,
    required String details,
    required String confirmLabel,
    required IconData icon,
  }) {
    final colors = context.relColors;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ClipboardImportSheet(
        title: title,
        badge: badge,
        name: name,
        details: details,
        confirmLabel: confirmLabel,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.md,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Badge chip
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderMuted),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.content_paste_rounded,
                      size: 13,
                      color: colors.action,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badge,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colors.action,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Card preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.actionSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: colors.action,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            details,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Dismiss',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
