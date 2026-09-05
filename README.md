# Jadwal

> A simple timetable tracker for teachers.

Jadwal turns a teacher's timetable into a calm, glanceable companion for the school day. Import a structured timetable once, then see what is happening now, what comes next, and when it is time to move — entirely offline.

## Why Jadwal?

Teachers should not have to decode a dense timetable between bells. Jadwal keeps the day clear:

- **Know the current period at a glance** — with live upcoming, active, and completed states.
- **Get local reminders** when a period begins.
- **Import a timetable in two simple steps** — use the in-app prompt to turn a timetable image into JSON, then import the file.
- **Keep your schedule private** — no account, server, or internet connection is needed after import.
- **Stay on track from the home screen** with an Android widget for today’s schedule.
- **Make it yours** with light and dark themes.

## Getting started

### What you need

- Flutter 3.x
- Dart 3.x
- An Android device or emulator

### Run locally

```bash
flutter pub get
flutter run
```

On first launch, Jadwal guides you through creating and importing your timetable. The imported data stays on your device.

## How it works

1. Tap **Copy Prompt** in Jadwal.
2. Paste the prompt into an AI tool along with a photo of your timetable.
3. Save the returned timetable JSON file.
4. Tap **Upload JSON File** in Jadwal and select it.

Jadwal validates the file before saving it, then schedules reminders for the remaining periods of the day.

## Technology

Built with Flutter and Material 3. The app uses local storage for the timetable, local notifications for reminders, and a home-screen widget for Android.

## Project structure

```text
lib/
├── constants/   # Timetable prompt, day mapping, schedule and visual tokens
├── models/      # Period model and its live status logic
├── screens/     # Setup, editing and daily timetable experiences
├── services/    # Storage, validation, notifications and widget data
├── theme/       # Material 3 theme and design primitives
└── widgets/     # Reusable timetable UI
```

## Notes

- Jadwal is designed for Android first.
- Notification delivery can depend on Android’s notification and exact-alarm permissions, especially on manufacturer-customized devices.
- Timetable times use the format `h:mm AM/PM`, for example `2:00 PM`.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
