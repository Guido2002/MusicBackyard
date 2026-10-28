# Verification and remaining scope

This is a functional local-first MVP and an implementation of the requested foundation plus several later vertical features. It is not a claim that every item in the full master prompt or every production acceptance criterion is finished.

## Automated and local verification

- Flutter analyzer: clean.
- Release-specific controller/security tests cover automatic wifi behavior, foreground resume, interval throttling, persisted track choice, APK recovery, source permissions, cancellation, exact GitHub redirect policy, semantic-version validation and Dutch settings. Eight Python release-automation tests cover version/track inputs, rollback prevention, isolated feeds, ref-update races and tool-independent certificate hashing. APK certificates are hashed from verified DER bytes rather than parsed human-readable signer headings.
- Unit/widget suite: 100 passing tests covering database create/read/update/delete and reopen, schema v1→v2 migration, transactional rollback, search/sort, structure persistence, transposition and slash chords, capo math, anchor editing, ChordPro/directive roundtrip, URL validation, update state/manifest policy, HTTP failures/redirect rejection, download cancellation/cleanup/integrity, portable attachment backups and malformed restore rejection, long PDF pagination, all four templates, A5 landscape, onboarding, creating a song, tablet navigation and 1.8× text scaling.
- Android API 37 emulator integration (four passing tests in total): create a song through the real UI, write lyrics, insert a slash chord, transpose, save, close the native SQLite connection, reopen it and verify the persisted content. An arbitrary APK path is rejected by the native installer gate.
- Android PDFium integration: generate a PDF, reload and extract its text, compare chord/word x coordinates within one point, and render the page to pixels.
- Direct and Play Android debug APKs build successfully. The ordinary direct app launches on the Android emulator. The custom icon and onboarding were visually checked.
- Added coverage: folder rename/reparent/delete, atomic rollback and concurrent-cycle rejection; clipboard tab roundtrips and malformed input, paste append/replace behavior, tuning and technique validation; capo changes across arrangements and cancellation; snapshot selection for an active arrangement.
- Android document checks cover all four PDF content presets and confirm absent content stays absent. The editor arrangement is checked through the actual performance and PDF export routes.
- The master prompt's real-user timing/usability acceptance criteria have not been validated with musicians.

## Live Android release verification

The public stable release **1.1.1 (100006)** was built, production-signed, verified and published by GitHub Actions. The live stable feed and its complete APK download passed the app repository's HTTPS redirect, size and SHA-256 checks.

On the Android API 37 emulator, a production-signed installation **1.1.1 (100001)** detected the public stable feed and automatically downloaded its APK over wifi. The app's cryptographic/package/version checks passed. The normal source permission screen, Android update confirmation and Play Protect scan were followed. Android then reported **100006** installed. The existing song **Updatecontrole** and its full lyric **Bewaar dit eigen nummer tijdens de update.** remained present after replacement.

Evidence: [automatic download](screenshots/update-download.png), [system confirmation](screenshots/update-confirmation.png), [song retained after update](screenshots/update-retained-song.png). These tests used the emulator; the connected physical phone was not modified.

The public beta release **1.1.2-beta.1 (100007)** also passed its GitHub release workflow and the full live download/redirect/size/SHA-256 check. With the beta preference persisted, restarting the stable app automatically detected and downloaded beta without pressing the manual check/download buttons. Cancelling Android's installer returned to the app and **Opnieuw proberen → Installeren** reopened the installer successfully. After normal confirmation/Play Protect scanning, Android reported **100007 / 1.1.2-beta.1** installed, and the song and full lyric were retained again. Switching back to stable correctly offered no downgrade to **100006** and explained that a newer stable build would be offered later. Evidence: [automatic beta download completed](screenshots/update-beta-ready.png), [stable selection on the newer installed beta](screenshots/update-channel-no-downgrade.png).

## Production update gates still requiring physical devices/store accounts

The Android release infrastructure now includes public stable/beta feeds, encrypted Actions signing secrets, a durable production key and tagged/manual release automation. See `distribution.md` for endpoints, key recovery, release commands and the first-install transition from old debug builds. App Store/Play Store publication still requires store accounts.

The complete direct-APK success flow above passed on the emulator. Before broad rollout, repeat it on real supported Android devices and exercise:

1. No connectivity, network interruption, retry, insufficient storage, concurrent manual checks and cancellation during a real download.
2. Wrong package, older/wrong version code, corrupted signature, wrong signer certificate, and a correct signed APK.
3. Missing source-install permission, permission denial/return, installer cancellation, install blocked by device policy and a successful user-confirmed replacement.
4. Google Play install ownership plus the official Play in-app update API in a test track; inspect the Play build for absence of direct-install permissions/provider.
5. iOS App Store listing, file import/export, microphone permissions and playback on physical devices.

The native preflight uses Android's APK signature verifier library and compares the verified signer certificate set against the installed package. Native cryptographic checks are implemented and compile, but the complete positive/negative signing matrix is not claimed as device-tested. Installer handoff is not proof of installation success.

## Deliberately remaining product scope

- Receiving documents directly from the Android/iOS share sheet; use the implemented file picker meanwhile.
- OCR for scanned PDFs, specialized notation recognition and reliable conversion of arbitrary complex PDF layouts. Scans remain viewable original attachments with editable manual text.
- Spotify OAuth/metadata/playback; the implemented MVP only validates/stores/opens official track URLs.
- Rich checklist/highlight note editing; current notes are plain text (including manually typed checklist characters).
- Advanced tab rhythm/playback and a comprehensive fingering library/finger numbering. Tablature clipboard import/export, zoom and suggested capo alternatives are implemented. Imported ASCII uses a deterministic character grid when no fixed eight-slot grid can be inferred; long bars are split and advanced rhythmic notation is not inferred.
- Per-section highlight tools and user-configurable PDF font selection. Folder rename/reparent/delete and separate lyrics/chords/tabs PDF content presets are implemented.
- A true tablet split-view editor and large-library lazy/paginated database search. Current tablets have a navigation rail and responsive document controls.
- Automatic App Store version lookup; iOS opens its configured official store listing.
- Broad accessibility audits, actual Bluetooth pedal hardware validation, microphone interruption/background tests and performance benchmarks on large real libraries/documents.

Physical attachment files are retained after logical deletion so undo/copies cannot lose their content. A future transactional garbage collector can reclaim files after reference and backup checks. Portable backups currently cover the music library and attachments, not all app preferences. Keep regular external backups before deleting the application.

## Local environment

Verified on 28 October 2026 with Flutter 3.47.8 / Dart 3.13.7 and Android SDK 37. The connected physical device was not modified; tests/installations used the emulator. Full Xcode and CocoaPods are missing, so iOS builds and simulator runs could not be verified here. Native PDFium hook discovery emits notices about these missing Apple SDKs during some host tests; Android builds and the relevant tests still pass.
