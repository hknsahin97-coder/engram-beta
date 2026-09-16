# Engram

Capture something in seconds, remember it for good. An offline-first spaced
repetition app for Android, built with Flutter and
[FSRS](https://pub.dev/packages/fsrs).

## What makes it different

Tone. No streaks, no gamification, no blaming language — and you are never shown
how many reviews you owe.

- **A daily cap.** Only a set number of due cards reach today's session; the
  rest wait without piling onto you.
- **Forgiving after a break.** A card more than a week overdue is scheduled as
  if a week had passed, so time away does not collapse your deck. The real
  interval is still recorded.
- **No backlog counter.** The badge shows what is suggested for today, never
  the accumulated total. The code has no field for that total, so no screen can
  display it.
- **Reminders that respect use.** One reminder at a time you choose, skipped on
  a day you have already reviewed — opening the app to capture something does
  not count as reviewing.

## Features

**Capture** — text; camera (tap for a photo, press and hold for video); import a
recent photo or video, or a page from a PDF, and crop it; audio (press and
hold). You can also share text into Engram from another app without opening it.

**Review** — a vertical feed of mixed media, with four ratings mapped directly
onto FSRS: No idea · Barely · Almost · Got it.

**Library** — every card in a grid, with search, sorting, and filters by media
type and learning level (New, Weak, Learning, Known).

**Your data** — everything stays on the device. No account, no analytics, no
network requests. Export writes your cards, review history, settings and media
to a folder you choose. See [PRIVACY.md](PRIVACY.md).

## Status

Beta, Android. The iOS build compiles in CI but has not been released. Not yet
available: an editor for trimming audio and video, and a home screen widget.

## Building

| | |
|---|---|
| Flutter | 3.32.4 (Dart 3.8.1) |
| JDK | 17 |
| Android SDK / NDK | 35 / 27.0.12077973 |
| minSdk | 24 |

```bash
cd engram
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates the Isar schema
flutter analyze
flutter test
```

Integration tests use a real Isar database and need a connected device:

```bash
flutter test integration_test -d <device-id>
```

Release builds are signed with the key described in
`engram/android/key.properties.example`; without that file they fall back to the
debug key.

```bash
flutter build appbundle --release
```

### Things worth knowing

- **Isar is pinned to 3.3.0, without a caret.** `isar_community` 3.3.1 ships a
  native library that does not match its Dart side and fails at run time; 3.3.2
  fixes that but needs Dart 3.9 or later.
- **`flutter analyze` does not check generated code.** `*.g.dart` is excluded,
  so after schema changes run `flutter test` as well.
- **Model files import `fsrs` without a prefix.** The Isar generator writes the
  enum types unprefixed, and a prefixed import breaks the generated code.
- **Every `DateTime` in the database is UTC.** Notification scheduling works in
  local time.
- **Media paths are stored relative** to the app's documents directory, which
  can move between iOS updates.

## Project layout

```
engram/
  lib/
    core/         theme, media storage, shared widgets, the share channel
    data/         Isar models and repositories
    domain/       FSRS scheduling, the review queue, notification planning, export
    features/     capture · review · library · settings · shell
  test/           unit and widget tests
  integration_test/
  tool/generate_icons.py
```

## License

[MIT](LICENSE). The bundled Fraunces and Inter fonts carry their own licences;
see [NOTICE](NOTICE).
