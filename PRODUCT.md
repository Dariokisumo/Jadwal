# Product

## Register

product

## Users

Teachers at school. They open the app between classes or at the start of the day to check which period is next, what room they need to be in, and whether they have a break. Context is fast-glance on a phone between bells — no time to navigate complex UI.

## Product Purpose

Turn a photo of a teacher's paper timetable into a live, time-aware tracker. The app shows the current period, upcoming periods, and finished periods at a glance, with local notifications at each period start. Fully offline — no account, no server, no internet required after initial JSON import.

## Brand Personality

Clean, calm, reliable. The interface should feel like a quiet tool that just works — not flashy, not playful, not corporate. Trustworthy and effortless.

## Anti-references

- Cluttered dashboard UIs with too many cards and stats (e.g. Notion templates)
- Playful/rounded "edu-tech" aesthetics with cartoon illustrations
- Corporate SaaS dashboards with gradients, glassmorphism, or dense data tables
- Any design that requires learning before using

## Design Principles

1. **One glance is enough.** The most important information (current period) must be visible without scrolling or tapping.
2. **Offline-first simplicity.** No network calls, no accounts, no cloud. Every feature works without connectivity.
3. **Earned trust through reliability.** Notifications fire on time, the timer is accurate, the status is always correct. A broken schedule tracker is worse than no tracker.
4. **Minimal cognitive load.** Two-step setup, then zero configuration. The teacher should never have to think about the app itself.
5. **Respect the school day.** The UI rhythm matches the school rhythm — periods start and end, breaks happen, the day finishes. The app reflects that structure naturally.

## Accessibility & Inclusion

- Material 3 with system theme support (light/dark)
- Readable font sizes (Inter at 13-17px for body/headings)
- Sufficient color contrast via saffron gold primary on white/dark surfaces
- Screen reader support via Semantics widgets on key elements
- Reduced motion: not yet implemented — should be added for `flutter_animate` transitions
