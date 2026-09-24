import 'package:flutter/material.dart';

import 'primitives.dart';
import 'relational_colors.dart';

const String _kFontFamily = 'Geist';

class _AccentSet {
  const _AccentSet(this.light, this.subtle, this.dark, this.darkContainer);
  final Color light;
  final Color subtle;
  final Color dark;
  final Color darkContainer;
}

const Map<String, _AccentSet> _kAccents = {
  'navy': _AccentSet(
    Primitives.actionNavy,
    Primitives.actionNavySubtle,
    Primitives.actionNavyDark,
    Primitives.actionNavyDarkContainer,
  ),
  'copper': _AccentSet(
    Primitives.actionCopper,
    Primitives.actionCopperSubtle,
    Primitives.actionCopperDark,
    Primitives.actionCopperDarkContainer,
  ),
  'sage': _AccentSet(
    Primitives.actionSage,
    Primitives.actionSageSubtle,
    Primitives.actionSageDark,
    Primitives.actionSageDarkContainer,
  ),
  'slate': _AccentSet(
    Primitives.actionSlate,
    Primitives.actionSlateSubtle,
    Primitives.actionSlateDark,
    Primitives.actionSlateDarkContainer,
  ),
  'default': _AccentSet(
    Primitives.actionGold,
    Primitives.actionGoldSubtle,
    Primitives.actionGoldDark,
    Primitives.actionGoldDarkContainer,
  ),
};

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
  final set = _kAccents[accent] ?? _kAccents['default']!;
  final actionColor = isDark ? set.dark : set.light;
  final actionSubtle = isDark ? set.darkContainer : set.subtle;
  final activeGlow = actionColor;

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

  final relationalColors = RelationalColors(
    action: actionColor,
    actionSubtle: actionSubtle,
    onAction: Colors.white,
    danger: dangerColor,
    dangerSubtle: dangerSubtleColor,
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
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? surfaceContainerHighestColor : const Color(0xFF1E1C18),
      contentTextStyle: TextStyle(
        fontFamily: _kFontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: isDark ? textPrimaryColor : const Color(0xFFFDFBF7),
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? borderSubtleColor : const Color(0x2AFFFFFF),
          width: 1,
        ),
      ),
      elevation: 4,
      actionTextColor: actionColor,
      closeIconColor: isDark ? textSecondaryColor : const Color(0xFFB8B2A6),
    ),
    extensions: [
      relationalColors,
    ],
  );
}
