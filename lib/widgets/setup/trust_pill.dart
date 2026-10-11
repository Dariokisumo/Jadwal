import 'package:flutter/material.dart';

import '../../theme/relational_colors.dart';

/// Trust pill — pure presentational extract from SetupScreen._buildTrustPill.
class TrustPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const TrustPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.action),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
