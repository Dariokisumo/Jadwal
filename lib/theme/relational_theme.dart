import 'package:flutter/material.dart';

import 'primitives.dart';
import 'relational_colors.dart';

const String _kFontFamily = 'Inter';

/// Build the light or dark [ThemeData] using the relational two-tier token system.
///
/// Handles both [Brightness] values and the user's selected accent preset ([accent]),
/// generating a coherent Material 3 [ColorScheme] with high-chroma fidelity alongside
/// the authoritative [RelationalColors] theme extension.
ThemeData buildRelationalTheme(
  Brightness brightness, {
  String accent = 'default',
}) {
  final isDark = brightness == Brightness.dark;

  // Resolve accent seed and variants per brightness
  final Color actionColor;
  final Color actionHover;
  final Color actionSubtle;
  final Color activeGlow;

  switch (accent) {
    case 'navy':
      actionColor = isDark ? Primitives.actionNavyDark : Primitives.actionNavy;
      actionHover =
          isDark ? Primitives.actionNavy : Primitives.actionNavyHover;
      actionSubtle = isDark
          ? Primitives.actionNavyDarkContainer
          : Primitives.actionNavySubtle;
      activeGlow = isDark ? Primitives.actionNavyDark : Primitives.actionNavy;
      break;
    case 'copper':
      actionColor =
          isDark ? Primitives.actionCopperDark : Primitives.actionCopper;
      actionHover =
          isDark ? Primitives.actionCopper : Primitives.actionCopperHover;
      actionSubtle = isDark
          ? Primitives.actionCopperDarkContainer
          : Primitives.actionCopperSubtle;
      activeGlow =
          isDark ? Primitives.actionCopperDark : Primitives.actionCopper;
      break;
    case 'sage':
      actionColor =
          isDark ? Primitives.actionSageDark : Primitives.actionSage;
      actionHover =
          isDark ? Primitives.actionSage : Primitives.actionSageHover;
      actionSubtle = isDark
          ? Primitives.actionSageDarkContainer
          : Primitives.actionSageSubtle;
      activeGlow =
          isDark ? Primitives.actionSageDark : Primitives.actionSage;
      break;
    case 'slate':
      actionColor =
          isDark ? Primitives.actionSlateDark : Primitives.actionSlate;
      actionHover =
          isDark ? Primitives.actionSlate : Primitives.actionSlateHover;
      actionSubtle = isDark
          ? Primitives.actionSlateDarkContainer
          : Primitives.actionSlateSubtle;
      activeGlow =
          isDark ? Primitives.actionSlateDark : Primitives.actionSlate;
      break;
    case 'default':
    default:
      actionColor = isDark ? Primitives.actionGoldDark : Primitives.actionGold;
      actionHover =
          isDark ? Primitives.actionGold : Primitives.actionGoldHover;
      actionSubtle = isDark
          ? Primitives.actionGoldDarkContainer
          : Primitives.actionGoldSubtle;
      activeGlow = isDark ? Primitives.actionGoldDark : Primitives.actionGold;
      break;
  }

  final surfaceColor =
      isDark ? Primitives.surfaceDark : Primitives.surfaceLight;
  final surfaceContainerColor = isDark
      ? Primitives.surfaceContainerDark
      : Primitives.surfaceContainerLight;
  final surfaceContainerHighestColor = isDark
      ? Primitives.surfaceContainerHighestDark
      : Primitives.surfaceContainerHighestLight;
  final textPrimaryColor = isDark ? Primitives.textDark : Primitives.textLight;
  final textSecondaryColor =
      isDark ? Primitives.textSecondaryDark : Primitives.textSecondaryLight;
  final borderSubtleColor =
      isDark ? Primitives.borderSubtleDark : Primitives.borderSubtleLight;
  final borderMutedColor =
      isDark ? Primitives.borderMutedDark : Primitives.borderMutedLight;
  final dangerColor = isDark ? Primitives.dangerDark : Primitives.danger;
  final dangerSubtleColor =
      isDark ? Primitives.dangerSubtleDark : Primitives.dangerSubtleLight;
  final successColor = isDark ? Primitives.successDark : Primitives.success;
  final successSubtleColor =
      isDark ? Primitives.successSubtleDark : Primitives.successSubtleLight;

  final relationalColors = RelationalColors(
    action: actionColor,
    actionHover: actionHover,
    actionSubtle: actionSubtle,
    onAction: Colors.white,
    danger: dangerColor,
    dangerSubtle: dangerSubtleColor,
    success: successColor,
    successSubtle: successSubtleColor,
    surface: surfaceColor,
    surfaceContainer: surfaceContainerColor,
    surfaceContainerHighest: surfaceContainerHighestColor,
    textPrimary: textPrimaryColor,
    textSecondary: textSecondaryColor,
    borderSubtle: borderSubtleColor,
    borderMuted: borderMutedColor,
    activeGlow: activeGlow,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: actionColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: actionColor,
    primaryContainer: actionSubtle,
    onPrimary: Colors.white,
    onPrimaryContainer: actionColor,
    surface: surfaceColor,
    onSurface: textPrimaryColor,
    onSurfaceVariant: textSecondaryColor,
    surfaceContainerHighest: surfaceContainerHighestColor,
    outline: borderMutedColor,
    outlineVariant: borderSubtleColor,
    error: dangerColor,
    errorContainer: dangerSubtleColor,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: _kFontFamily,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surfaceColor,
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderSubtleColor),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: textPrimaryColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainerColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderSubtleColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderSubtleColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: actionColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: dangerColor),
      ),
    ),
    extensions: [
      relationalColors,
    ],
  );
}
