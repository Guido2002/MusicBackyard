# MusicBackyard

An offline-first Flutter workspace for musicians. The interface is Dutch; code and technical documentation are English.

## Run

Requires Flutter 3.47.8 / Dart 3.13.7 or a compatible newer SDK, and Android SDK 37. Android minimum SDK is 24. No account, API key, backend, or network connection is required for the music library.

```sh
flutter pub get
flutter run --flavor direct
```

For a particular emulator, add `-d emulator-5554`. Use `--flavor play` for Google Play builds. iOS uses `flutter run -d <simulator-id>` without an Android flavor and requires full Xcode plus the platform plugin dependencies.

## Implemented

- Three-step optional-instrument onboarding, light/dark themes, generated Dutch ARB localization, and five navigation destinations with a tablet navigation rail.
- Durable SQLite storage with schema migration, nested folders with rename/reparent/safe deletion, search in title/artist/lyrics/notes/tags, filters, sorting, favorites, copying, archive, trash and restore.
- Song metadata, multiple arrangements, editable and reorderable sections, chords anchored to text offsets, cursor/word chord insertion, undo/redo, autosave, find/replace, transposition including slash chords, capo/sounding-key display, pitch-preserving capo changes and open-shape alternatives, and common native chord diagrams.
- Structured six-string tablature with measures, fret/technique entry, alternate tunings, zoom, ASCII view and validated clipboard import/export.
- ChordPro import/export preserving unknown directives; plain-text chord-line detection; PDF/image import with original attachment, PDF text extraction and editable review. Scans stay attachments without invented text.
- Local audio recording/playback, song notes, attachment viewer, and validated Spotify track links opened externally.
- Setlists with reorder controls and drag/drop, pauses, notes, duration, per-entry arrangement/transpose/capo overrides, duplicate, performance and PDF book export.
- Dark performance mode with adjustable font, chords, auto-scroll, speed, previous/next, saved position, screen wake lock and configurable keyboard HID pedal navigation.
- Offline PDF generation using bundled OFL fonts, separate lyrics/chords/tabs content modes, four templates, A4/A5, orientation, margins, text/spacing controls, page numbers, cover/contents for bandbooks, headers/footers, notes/tabs, preview, file save, sharing and printing.
- Portable library backups including attachment bytes; validated staged restore and transactional database replacement.
- Stable/beta release channels, automatic foreground/resume checks and optional verified wifi downloads. Every feature/fix push to main automatically versions, tests, signs and publishes a stable APK and advances its update feed. Tagged/manual beta releases remain available. Separate direct-APK/Play/App Store update routes. Direct downloads have explicit HTTPS/host policy, cancellation/progress, size/hash verification, cryptographic APK signature verification, package/version/signer checks and user-confirmed Android installation. See [distribution](docs/distribution.md).
- A generated custom launcher icon installed in Android and iOS assets. See [branding](docs/branding.md).

## Releases

Install production APKs from [GitHub Releases](https://github.com/Guido2002/MusicBackyard/releases). New feature/fix pushes to `main` automatically create a versioned stable release. Use `feat:` / `fix:` commit messages for automatic semantic versioning. Choose stable/beta in **Meer → Profiel → App-updates**. See [release workflow and signing](docs/distribution.md) before publishing.

## Validate

```sh
dart run tool/prepare_test_environment.dart
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart --flavor direct -d emulator-5554
flutter build apk --debug --flavor direct
flutter build apk --debug --flavor play
```

The integration test uses its own uniquely named song in the emulator library and removes it after successful validation. Avoid running it on a personal production installation. Release builds require your own signing configuration; they never silently use a debug key.

`flutter pub get` may report newer packages incompatible with dependency constraints. This is an informational notice; the tested dependency versions are recorded in `pubspec.lock`. Use `flutter pub outdated` to distinguish updates allowed by the current constraints from new major versions or packages pinned by Flutter. Validate dependency upgrades with the checks above before releasing them.

See [architecture](docs/architecture.md), [verification and remaining scope](docs/verification.md), and [distribution](docs/distribution.md). The active editor arrangement is preserved in performance and export. Generated example songs are not inserted into users' libraries.
