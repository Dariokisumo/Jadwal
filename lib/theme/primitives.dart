import 'package:flutter/material.dart';

/// Tier-1 Primitives — raw color values.
///
/// Widgets never consume these directly. Always read semantic aliases
/// from [RelationalColors] via `context.relColors` or `Theme.of(context).extension<RelationalColors>()!`.
abstract final class Primitives {
  // ── Accent: Gold (Default — Saffron) ──────────────────────────────────────
  static const Color actionGold = Color(0xFFD4930D);
  static const Color actionGoldSubtle = Color(0xFFFFF3D6);
  static const Color actionGoldDark = Color(0xFFF0A830);
  static const Color actionGoldDarkContainer = Color(0xFF3D3015);

  // ── Accent: Navy ──────────────────────────────────────────────────────────
  static const Color actionNavy = Color(0xFF1E3A5F);
  static const Color actionNavySubtle = Color(0xFFE8EFF7);
  static const Color actionNavyDark = Color(0xFF5A89C7);
  static const Color actionNavyDarkContainer = Color(0xFF122238);

  // ── Accent: Copper ────────────────────────────────────────────────────────
  static const Color actionCopper = Color(0xFFC77D38);
  static const Color actionCopperSubtle = Color(0xFFFAEDE3);
  static const Color actionCopperDark = Color(0xFFE29A57);
  static const Color actionCopperDarkContainer = Color(0xFF3A2312);

  // ── Accent: Sage (Olive) ──────────────────────────────────────────────────
  static const Color actionSage = Color(0xFF4A6B53);
  static const Color actionSageSubtle = Color(0xFFEAF2EB);
  static const Color actionSageDark = Color(0xFF7CA886);
  static const Color actionSageDarkContainer = Color(0xFF1E2B21);

  // ── Accent: Slate (Parchment / Monochrome) ────────────────────────────────
  static const Color actionSlate = Color(0xFF4B5563);
  static const Color actionSlateSubtle = Color(0xFFF1F3F5);
  static const Color actionSlateDark = Color(0xFF9CA3AF);
  static const Color actionSlateDarkContainer = Color(0xFF252930);

  // ── Light Neutrals & Surfaces (Warm undertone) ────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFCF5);
  static const Color surfaceContainerLight = Color(0xFFF7F2E9);
  static const Color surfaceContainerHighestLight = Color(0xFFEDE7DC);
  static const Color textLight = Color(0xFF1A1612);
  static const Color textSecondaryLight = Color(0xFF5C5347);
  static const Color borderSubtleLight = Color(0xFFD6CFC5);
  static const Color borderMutedLight = Color(0xFF8A7E72);

  // ── Dark Neutrals & Surfaces (Deep warm black) ────────────────────────────
  static const Color surfaceDark = Color(0xFF1A1612);
  static const Color surfaceContainerDark = Color(0xFF231F1A);
  static const Color surfaceContainerHighestDark = Color(0xFF2D2822);
  static const Color textDark = Color(0xFFF5F2EB);
  static const Color textSecondaryDark = Color(0xFFB8B2A6);
  static const Color borderSubtleDark = Color(0xFF403A33);
  static const Color borderMutedDark = Color(0xFF665F56);

  // ── Semantic States ───────────────────────────────────────────────────────
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerDark = Color(0xFFF28B82);
  static const Color dangerSubtleLight = Color(0xFFF9DEDC);
  static const Color dangerSubtleDark = Color(0xFF410E0B);
}
