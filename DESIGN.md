---
name: Jadwal
description: Offline teacher timetable tracker with live period status and local notifications
colors:
  primary: "#D4930D"
  primary-container: "#FFF3D6"
  on-primary: "#FFFFFF"
  on-surface: "#1A1612"
  on-surface-variant: "#5C5347"
  surface: "#FFFCF5"
  surface-container-highest: "#EDE7DC"
  outline: "#8A7E72"
  outline-variant: "#D6CFC5"
  error: "#B3261E"
  error-container: "#F9DEDC"
  on-error-container: "#410E0B"
---

# Design System: Jadwal

## 1. Overview

**Creative North Star: "The Quiet Companion"**

Jadwal is a tool that sits in a teacher's pocket and does one thing well: tell them what's next. The design should feel like a quiet, reliable presence — never loud, never demanding attention, always there when needed. It earns trust through consistency, not decoration.

The visual language is rooted in restraint. One accent color carries all emphasis. Typography does the hierarchy work. Cards use subtle borders and tonal shifts rather than shadows or gradients. The interface disappears when the information is clear, and steps forward only when the user needs to act.

**Key Characteristics:**
- Selectable accent palette: three seed colors (gold, navy, copper) that the user can choose from. Each accent derives a full Material 3 palette.
- Warm-tinted surfaces — not cold gray, not generic cream
- Tonal layering over shadows for depth
- Typography-driven hierarchy with Inter at multiple weights
- Generous whitespace; the UI breathes
- Glowing accent on active state as the one moment of visual energy

## 2. Colors

The palette is built on an **OKLCH-perceptual two-tier token system** (the `flutter-relational` pattern). Raw OKLCH constants live in `Primitives`; semantic aliases consumed by widgets live in `RelationalColors`, accessed via `context.relColors`.

### Architecture

```
Tier 1 — Primitives (lib/theme/primitives.dart)
  Raw OKLCH constants: accent seeds, surface ramps, text, borders, danger, success.

Tier 2 — RelationalColors (lib/theme/relational_colors.dart)
  ThemeExtension with named semantic slots:
    surface, surfaceContainer, surfaceContainerHighest
    text, textSecondary
    borderSubtle, borderMuted
    action, actionSubtle, actionHover, activeGlow
    danger, dangerSubtle, success, successSubtle

buildRelationalTheme() (lib/theme/relational_theme.dart)
  Wires ColorScheme.fromSeed (M3 fidelity variant) + RelationalColors extension.
  Called with a Brightness and accent name from accentSeeds.
```

Widgets must use `context.relColors.*` for all color values. Direct `Theme.of(context).colorScheme` calls are not used in widget layer.

### Accent Seeds

Five user-selectable accents. Each derives a full M3 `ColorScheme` **and** fills the relational semantic slots.

| Name | Light Hex | Dark Hex | Notes |
|------|-----------|----------|-------|
| **Gold** (default) | `#D4930D` | `#F0A830` | Warm saffron. Scholarly. |
| **Navy** | `#1E3A5F` | `#5A89C7` | Cool contrast on warm surfaces. |
| **Copper** | `#C77D38` | `#E29A57` | Warm harmony on dark backgrounds. |
| **Sage** | `#4A6B53` | `#7CA886` | Calm, earthy olive/sage. |
| **Slate** | `#4B5563` | `#9CA3AF` | Ultra-minimalist newspaper-like monochrome. |

Container tints (light / dark):
- Gold: `#FFF3D6` / `#3D3015`
- Navy: `#E8EFF7` / `#122238`
- Copper: `#FAEDE3` / `#3A2312`
- Sage: `#EAF2EB` / `#1E2B21`
- Slate: `#F1F3F5` / `#252930`

### Surface Ramp (Warm Neutral — shared across all accents)

| Token | Light | Dark | Role |
|-------|-------|------|------|
| `surface` | `#FFFCF5` | `#1A1612` | Scaffold & card background |
| `surfaceContainer` | `#F7F2E9` | `#231F1A` | Input fill, secondary containers |
| `surfaceContainerHighest` | `#EDE7DC` | `#2D2822` | Finished card tint, overlays |

### Text & Borders

| Token | Light | Dark | Role |
|-------|-------|------|------|
| `text` | `#1A1612` | `#F5F2EB` | Primary text |
| `textSecondary` | `#5C5347` | `#B8B2A6` | Supporting text |
| `borderSubtle` | `#D6CFC5` | `#403A33` | Resting card borders |
| `borderMuted` | `#8A7E72` | `#665F56` | Dividers, finished states |

### Semantic Slots

- **`action`** — accent primary (e.g. `#D4930D` in Gold/Light)
- **`actionSubtle`** — accent container fill (e.g. `#FFF3D6`)
- **`actionHover`** — accent pressed/hover shade (e.g. `#BD7D00`)
- **`activeGlow`** — `action` with 55% opacity; used only on the active period card's animated glow
- **`danger`** — `#B3261E` (light) / `#CF6679` (dark)
- **`dangerSubtle`** — `#F9DEDC` (light) / `#4B1E22` (dark)
- **`success`** — `#386A2D` (light) / `#86C97A` (dark)
- **`successSubtle`** — `#DDF2D7` (light) / `#1B3317` (dark)

### Named Rules

**The Quiet Accent Rule.** `colors.action` appears on ≤15% of any given screen. Its rarity is what makes it work. If every element uses action color, nothing is emphasized.

**The No-Shadow Rule.** Depth is conveyed through tonal surface shifts (`surfaceContainer`, `surfaceContainerHighest`) and borders. The one exception is `colors.activeGlow` on the live period card — decorative emphasis, not structural depth.

**The Warmth Rule.** All surfaces carry a warm undertone derived from the saffron hue. Never cold gray. Never generic cream.

**The Token Rule.** New widgets must consume `context.relColors.*`. Never hardcode ARGB values in widget files. Add new primitives to `Primitives` and new aliases to `RelationalColors` if needed.

### Error

- **`danger`** (`#B3261E`): Validation errors, destructive actions.
- **`dangerSubtle`** (`#F9DEDC`): Error container background.

## 3. Typography

**Display Font:** Inter (with system fallback: -apple-system, BlinkMacSystemFont, sans-serif)
**Body Font:** Inter (with system fallback)
**Mono Font:** JetBrainsMono (for JSON code display only)

**Character:** Inter is a neutral, highly legible sans-serif. The pairing is single-family with weight variation — clean, modern, and invisible. It does its job without calling attention to itself, which matches the Quiet Companion ethos. Saffron gold provides the warmth that Inter's neutrality doesn't carry on its own.

### Hierarchy

- **Display** (Bold 700, 28px, tight line-height): App title on setup screen. Appears once per screen.
- **Headline** (Bold 700, 16-17px): Teacher name in app bar, section titles ("Notification Status"). Anchors each screen.
- **Title** (SemiBold 600, 20px): Period subject names on cards. The most important information on screen — must be readable in a glance.
- **Body** (Regular 400, 13-13.5px, 1.4 line-height): Descriptions, instructions, timestamps, classroom/time info. Max width constrained to comfortable reading.
- **Label** (Bold 700, 11px, +0.3 letter-spacing): ONGOING badge. (SemiBold 600, 13px): Period number in its container.

### Named Rules

**The Glance Rule.** The most important text on any screen (the current period subject) must be readable at arm's length. Title weight, 20px, high contrast against its background. No decorative treatments on this element.

## 4. Elevation

Jadwal uses tonal layering, not shadows. Cards sit flat on the surface with subtle borders and background tint shifts to separate them from the scaffold. Depth is communicated through:

- **Border contrast**: resting cards use `outlineVariant` borders; the active card uses a bold 2px `primary` border
- **Tonal fill**: finished cards fade into `surfaceContainerHighest` at 50% opacity; active cards tint with `primaryContainer`
- **One decorative exception**: the active period card pulses with an animated glow shadow (primary color, 6-18px blur) — this is emphasis, not depth

### Shadow Vocabulary

- **Active glow** (`box-shadow: 0 6px 18px rgba(212,147,13,0.15–0.55)`): Animated, pulsing. Used only on the currently-active period card. Respects `prefers-reduced-motion`.

### Named Rules

**The Flat-By-Default Rule.** Surfaces are flat at rest. Shadows appear only as a response to state (active period) or interaction (menu popup). No ambient drop shadows on cards, buttons, or containers.

## 5. Components

### PeriodCard

The core component. Three visual states that communicate period status at a glance.

- **Upcoming:** Clean surface background, `outlineVariant` border (1px), ink text. Period number in a 36px tonal square.
- **Active:** `primaryContainer` tint at 30% opacity, 2px `primary` border, bold subject text in primary color, animated glow shadow, pulsing "ONGOING" badge with dot.
- **Finished:** `surfaceContainerHighest` tint at 50% opacity, no border, `outline` text color, strikethrough on subject, "✓ Done" label.
- **Shape:** Rounded corners (12px radius).
- **Padding:** 16px horizontal, 14px vertical.
- **Internal layout:** Period number (36px square, 10px radius) → 14px gap → Subject + time info → Badge on right.

### Buttons

- **Primary (ElevatedButton):** Saffron gold background, white text, 10px radius, full-width, 14px vertical padding. Used for "Copy Prompt" and "Import Timetable."
- **Secondary (TextButton):** Transparent background, saffron text. Used for "Next Step →" and "Or upload a .json file."
- **Disabled:** `surfaceContainerHighest` background, `outline` text. Reduced contrast signals non-interactivity.
- **Hover / Focus:** Material 3 default ripple and focus ring.

### Day Chips (Selector)

- **Selected:** Saffron gold background, white text, 1.5px saffron border, 12px radius. Dot indicator below.
- **Unselected:** `surfaceContainerHighest` background, ink text, `outlineVariant` border.
- **Friday (rest day):** Saffron at 12% opacity background, saffron at 50% text, coffee icon instead of text, "OFF" label below.
- **Shape:** 40px square, 12px radius.
- **Spacing:** Evenly distributed across screen width with 12px horizontal padding.

### Step Cards (Setup)

- **Shape:** 14px radius, `outlineVariant` border (transitions to saffron-tinted when step is complete), surface background.
- **Padding:** 20px all sides.
- **Header:** Step number (26px saffron square, 8px radius) + title in Headline weight.
- **Content:** Body text, followed by interactive elements.

### Text Field (JSON Input)

- **Style:** `outlineVariant` border, 10px radius, `surfaceContainerHighest` at 30% fill.
- **Focus:** 2px primary border.
- **Font:** JetBrainsMono 12.5px for code entry.
- **Padding:** 14px internal.

### Diagnostics Bottom Sheet

- **Shape:** 20px top radius only.
- **Content:** Status rows with icon (green check / orange error) + label + optional "Fix" link in primary color.
- **Pending list:** Scrollable, max 180px height, 1px dividers.

### Popup Menu

- **Shape:** 14px radius, elevation 3, surface background.
- **Items:** 20px icon + 12px gap + 14px label text. "Theme" opens a bottom sheet.

## 6. Do's and Don'ts

### Do:

- **Do** use saffron gold (#D4930D) as the sole accent for emphasis, action, and active states.
- **Do** keep the primary accent on ≤15% of any given screen. Its rarity is what makes it work.
- **Do** use tonal shifts (surfaceContainerHighest, primaryContainer) for depth instead of shadows.
- **Do** use Inter Bold at 20px for period subject names — this is the most important information on screen.
- **Do** respect `prefers-reduced-motion`: the active card glow and pulsing dot should crossfade, not animate.
- **Do** use 12px radius on cards and 10px on buttons — consistent, not exaggerated.
- **Do** keep text high-contrast: Ink (#1C1B1F) on light surfaces, never muted gray for body text.

### Don't:

- **Don't** use box-shadows on cards, buttons, or containers. The active card glow is the only shadow in the system.
- **Don't** use gradient backgrounds or gradient text. The palette is flat and tonal.
- **Don't** use glassmorphism, blur effects, or backdrop-filter. The UI is solid and grounded.
- **Don't** use border-left or border-right as a colored accent stripe. Use full borders or tonal fills.
- **Don't** use rounded corners above 14px on cards. 12px is the standard; 14px only on step cards.
- **Don't** add decorative illustrations, doodles, or sketchy SVGs. The type system carries the visual interest.
- **Don't** invent new accent colors outside the `accentSeeds` map. Add entries to the map in `main.dart` and the dots in `theme_bottom_sheet.dart` instead.
- **Don't** put muted gray body text on a tinted near-white background — it fails contrast. Use Ink or a dark tint of the background's own hue.
