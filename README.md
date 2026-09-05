# Jadwal

> A simple timetable tracker for teachers.

Jadwal is an offline-first Flutter app that helps teachers keep the school day clear. Import a timetable once, then see the current period, what comes next, and receive local reminders — with no account or network required after setup.

## Features

- Live upcoming, active, and completed period states
- Local notifications at period start times
- Simple JSON timetable import with validation
- Android home-screen widget for today’s schedule
- Light and dark themes
- Private, offline storage on the device

## Getting started

### Requirements

- Flutter 3.x
- Dart 3.x
- An Android device or emulator

### Run locally

```bash
flutter pub get
flutter run
```

## Importing a timetable

1. In Jadwal, copy the built-in timetable prompt.
2. Use it with an AI tool and a photo of your timetable.
3. Save the returned JSON file.
4. Import the JSON file in Jadwal.

The app validates the timetable before saving it and schedules reminders for the remaining periods of the day.

## Project structure

```text
lib/        # Flutter application source
android/    # Android integration and home-screen widget
assets/     # Bundled fonts and design tokens
```

## License

GPL-3.0. See [LICENSE](LICENSE).
