import 'package:flutter/material.dart';

/// Tier-1 Primitives — raw color values derived in OKLCH.
///
/// Widgets never consume these directly. Always read semantic aliases
/// from [RelationalColors] via `context.relColors` or `Theme.of(context).extension<RelationalColors>()!`.
///
/// Every value is derived with perceptual uniformity in OKLCH. Keep the OKLCH
/// formula comments next to each constant for future palette derivations.
abstract final class Primitives {
  // ── Accent: Gold (Default — Saffron) ──────────────────────────────────────
  // oklch(0.7096 0.1463 76.69) — primary warm scholarly accent
  static const Color actionGold = Color(0xFFD4930D);
  // oklch(0.6396 0.1463 76.69) — consistent −0.07 L hover/press step
  static const Color actionGoldHover = Color(0xFFBD7D00);
  // oklch(0.96 0.04 76.69) — subtle light container wash
  static const Color actionGoldSubtle = Color(0xFFFFF3D6);
  // oklch(0.76 0.15 76.69) — bright gold for dark mode
  static const Color actionGoldDark = Color(0xFFF0A830);
  // oklch(0.28 0.04 75.0) — deep container wash for dark mode
  static const Color actionGoldDarkContainer = Color(0xFF3D3015);

  // ── Accent: Navy ──────────────────────────────────────────────────────────
  // oklch(0.3462 0.0736 256.04) — cool authority accent
  static const Color actionNavy = Color(0xFF1E3A5F);
  // oklch(0.2762 0.0736 256.04) — hover/press step
  static const Color actionNavyHover = Color(0xFF142B47);
  // oklch(0.95 0.02 256.04) — subtle light container wash
  static const Color actionNavySubtle = Color(0xFFE8EFF7);
  // oklch(0.62 0.11 256.04) — bright navy for dark mode
  static const Color actionNavyDark = Color(0xFF5A89C7);
  // oklch(0.22 0.04 256.04) — deep container wash for dark mode
  static const Color actionNavyDarkContainer = Color(0xFF122238);

  // ── Accent: Copper ────────────────────────────────────────────────────────
  // oklch(0.6555 0.1240 60.55) — warm earthy accent
  static const Color actionCopper = Color(0xFFC77D38);
  // oklch(0.5855 0.1240 60.55) — hover/press step
  static const Color actionCopperHover = Color(0xFFB06A26);
  // oklch(0.95 0.03 60.55) — subtle light container wash
  static const Color actionCopperSubtle = Color(0xFFFAEDE3);
  // oklch(0.72 0.13 60.55) — bright copper for dark mode
  static const Color actionCopperDark = Color(0xFFE29A57);
  // oklch(0.24 0.04 60.55) — deep container wash for dark mode
  static const Color actionCopperDarkContainer = Color(0xFF3A2312);

  // ── Light Neutrals & Surfaces (Warm undertone) ────────────────────────────
  // oklch(0.985 0.012 85.0) — clean warm surface
  static const Color surfaceLight = Color(0xFFFFFCF5);
  // oklch(0.96 0.015 85.0) — input field & elevated card container
  static const Color surfaceContainerLight = Color(0xFFF7F2E9);
  // oklch(0.93 0.02 85.0) — finished card tint & unselected chip background
  static const Color surfaceContainerHighestLight = Color(0xFFEDE7DC);
  // oklch(0.18 0.015 65.0) — Ink: high-contrast body & subject headings
  static const Color textLight = Color(0xFF1A1612);
  // oklch(0.42 0.02 65.0) — Secondary Ink: timestamps, room tags
  static const Color textSecondaryLight = Color(0xFF5C5347);
  // oklch(0.85 0.012 65.0) — Subtle divider & resting card frame
  static const Color borderSubtleLight = Color(0xFFD6CFC5);
  // oklch(0.60 0.015 65.0) — Muted border on finished cards & disabled states
  static const Color borderMutedLight = Color(0xFF8A7E72);

  // ── Dark Neutrals & Surfaces (Deep warm black) ────────────────────────────
  // oklch(0.18 0.015 65.0) — deep warm black surface
  static const Color surfaceDark = Color(0xFF1A1612);
  // oklch(0.22 0.015 65.0) — elevated dark container
  static const Color surfaceContainerDark = Color(0xFF231F1A);
  // oklch(0.26 0.015 65.0) — finished card & unselected chip fill
  static const Color surfaceContainerHighestDark = Color(0xFF2D2822);
  // oklch(0.94 0.01 75.0) — high-contrast text on dark surfaces
  static const Color textDark = Color(0xFFF5F2EB);
  // oklch(0.75 0.01 75.0) — secondary text on dark surfaces
  static const Color textSecondaryDark = Color(0xFFB8B2A6);
  // oklch(0.35 0.015 65.0) — subtle border for dark cards
  static const Color borderSubtleDark = Color(0xFF403A33);
  // oklch(0.50 0.015 65.0) — muted border for dark finished items
  static const Color borderMutedDark = Color(0xFF665F56);

  // ── Semantic States ───────────────────────────────────────────────────────
  // oklch(0.52 0.20 25.0) — danger & destructive actions (light)
  static const Color danger = Color(0xFFB3261E);
  // oklch(0.72 0.16 25.0) — danger for dark mode
  static const Color dangerDark = Color(0xFFF28B82);
  // oklch(0.93 0.04 25.0) — danger container (light)
  static const Color dangerSubtleLight = Color(0xFFF9DEDC);
  // oklch(0.25 0.07 25.0) — danger container (dark)
  static const Color dangerSubtleDark = Color(0xFF410E0B);

  // oklch(0.58 0.16 142.0) — success / verified / done (light)
  static const Color success = Color(0xFF2E7D32);
  // oklch(0.77 0.14 142.0) — success for dark mode
  static const Color successDark = Color(0xFF81C784);
  // oklch(0.96 0.03 142.0) — success container (light)
  static const Color successSubtleLight = Color(0xFFE8F5E9);
  // oklch(0.28 0.05 142.0) — success container (dark)
  static const Color successSubtleDark = Color(0xFF1B381E);
}
