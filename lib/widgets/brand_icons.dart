import 'package:flutter/material.dart';

/// Brand icons for AI assistants, mapped to the closest Material Icons.
/// Ponytail: single widget — callers pass the brand [icon] + brand [color].
class BrandIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const BrandIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 20,
  });

  // Closest Material matches for the official brand marks.
  static const IconData geminiIcon = Icons.auto_awesome;
  static const IconData chatGptIcon = Icons.chat_bubble_outline;
  static const IconData claudeIcon = Icons.flare;

  // Official brand colors (preserved from the merged classes).
  static const Color geminiColor = Color(0xFF1A73E8);
  static const Color chatGptColor = Color(0xFF10A37F);
  static const Color claudeColor = Color(0xFFD97757);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Icon(icon, color: effectiveColor, size: size);
  }
}
