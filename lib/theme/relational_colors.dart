import 'package:flutter/material.dart';

/// Tier-2 Semantic Aliases — the only color tokens consumed by UI widgets.
///
/// Registered via `ThemeData.extensions` and accessed effortlessly with
/// `context.relColors` (or `Theme.of(context).extension<RelationalColors>()!`).
@immutable
class RelationalColors extends ThemeExtension<RelationalColors> {
  const RelationalColors({
    required this.action,
    required this.actionHover,
    required this.actionSubtle,
    required this.onAction,
    required this.danger,
    required this.dangerSubtle,
    required this.success,
    required this.successSubtle,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHighest,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderSubtle,
    required this.borderMuted,
    required this.activeGlow,
  });

  /// Primary interactive and active state accent color.
  final Color action;

  /// Pressed, focused, or hover state for action elements (−0.07 L shift).
  final Color actionHover;

  /// Subtle container tint for active cards, ongoing badges, and avatars.
  final Color actionSubtle;

  /// High-contrast content color when placed directly on [action].
  final Color onAction;

  /// Semantic error / destructive action color.
  final Color danger;

  /// Subtle container tint for error alerts.
  final Color dangerSubtle;

  /// Semantic success / verified / completed color.
  final Color success;

  /// Subtle container tint for completed badges.
  final Color successSubtle;

  /// Base scaffold and surface background.
  final Color surface;

  /// Secondary elevated surface (text fields, elevated sheets).
  final Color surfaceContainer;

  /// Tonal fill for finished cards, chips, and dividers.
  final Color surfaceContainerHighest;

  /// High-contrast primary text (headings, subject names, body).
  final Color textPrimary;

  /// Supporting secondary text (timestamps, room tags, subtitles).
  final Color textSecondary;

  /// Subtle border for resting cards and soft dividers.
  final Color borderSubtle;

  /// Muted border for finished cards, disabled states, and outlines.
  final Color borderMuted;

  /// Accent glow color for the active period card pulse.
  final Color activeGlow;

  @override
  RelationalColors copyWith({
    Color? action,
    Color? actionHover,
    Color? actionSubtle,
    Color? onAction,
    Color? danger,
    Color? dangerSubtle,
    Color? success,
    Color? successSubtle,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHighest,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderSubtle,
    Color? borderMuted,
    Color? activeGlow,
  }) {
    return RelationalColors(
      action: action ?? this.action,
      actionHover: actionHover ?? this.actionHover,
      actionSubtle: actionSubtle ?? this.actionSubtle,
      onAction: onAction ?? this.onAction,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderMuted: borderMuted ?? this.borderMuted,
      activeGlow: activeGlow ?? this.activeGlow,
    );
  }

  @override
  RelationalColors lerp(ThemeExtension<RelationalColors>? other, double t) {
    if (other is! RelationalColors) return this;
    return RelationalColors(
      action: Color.lerp(action, other.action, t)!,
      actionHover: Color.lerp(actionHover, other.actionHover, t)!,
      actionSubtle: Color.lerp(actionSubtle, other.actionSubtle, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHighest:
          Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderMuted: Color.lerp(borderMuted, other.borderMuted, t)!,
      activeGlow: Color.lerp(activeGlow, other.activeGlow, t)!,
    );
  }
}

/// Syntactic sugar to access relational colors cleanly from any [BuildContext].
extension RelationalTheme on BuildContext {
  RelationalColors get relColors =>
      Theme.of(this).extension<RelationalColors>()!;
}
