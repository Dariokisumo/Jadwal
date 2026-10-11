import 'package:flutter/material.dart';

import '../constants/spacing.dart';
import '../theme/relational_colors.dart';

/// Canonical bottom-sheet chrome — drag handle + surface + scroll + SafeArea.
/// Replaces 6 copy-pasted sheet scaffolds.
class AppSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;

  const AppSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    double maxHeightFactor = 0.9,
  }) {
    final colors = context.relColors;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.md,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: builder(ctx),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: child);
  }
}

/// Shared drag handle — 36×4 pill in [RelationalColors.borderSubtle].
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colors.borderSubtle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
