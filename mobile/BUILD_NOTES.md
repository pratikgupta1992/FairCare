# FairCare — Cross-Platform Scaffold Build Notes

Built 2026-10-21 (scaffold phase). The Android Kotlin app at the repo
root was used read-only as the reference and was not modified.

## Environment

- Flutter **3.47.7** (stable, Dart 3.13.5) installed at
  `~/workspace/tools/flutter` from the official Linux x64 tarball.
  Add it to PATH before any command below:
  `export PATH="$HOME/workspace/tools/flutter/bin:$PATH"`
- This VM is RAM-tight (~350 MB available during the build). All
  steps were run serially. Analyze and tests ran fine; a full
  Android APK build was **not attempted** this phase (see below).

## What was built

Project created with
`flutter create --org com.faircare --project-name faircare --platforms=android,ios .`
(bundle id / application id: `com.faircare.faircare`), then the
generated `lib/main.dart` and `test/widget_test.dart` were replaced.

```
mobile/lib/
  main.dart                     App entry, Material 3, bottom nav:
                                Today / Babies / Analytics / Settings
  models.dart                   Baby, Caregiver, CareTask, LogEntry —
                                ported from data/Entities.kt, plus the
                                12 default tasks from Db.kt verbatim
  fairness.dart                 Port of logic/Fairness.kt: weightedPoints,
                                splitDayNight, computeFairness, verdictFor,
                                hourlyDominant, startOfDay, color hex
  repository.dart               FairCareRepository interface +
                                LocalFairCareRepository (working local
                                backend: in-memory state persisted as JSON
                                via shared_preferences) + connect-code
                                generation (6 chars, unambiguous alphabet)
  firebase_repository_stub.dart FirebaseFairCareRepository implementing
                                the same interface; every method throws
                                UnimplementedError. NO fake Firebase
                                config anywhere. Header documents the
                                planned Firestore schema.
  prefs_store.dart              KeyValueStore over shared_preferences
  app_controller.dart           Per-user state: joined babies, selected
                                baby, user name, per-baby default
                                caregiver — persisted locally
  today_screen.dart             Today's entries for the selected baby,
                                tap to edit, FAB to log care
  log_entry_form.dart           Task + caregiver + date/start/end + note.
                                Caregiver pre-selects the user's default
                                role for the baby; changeable per entry.
                                Mom-only tasks warn if a non-Mom is picked.
  babies_screen.dart            Joined babies, create baby (shows its
                                connect code), join by code, baby detail
                                with copy/regenerate code
  analytics_screen.dart         Fairness score + verdict card, weighted
                                points bars per caregiver, parent share %,
                                outsourced %, per-task breakdown
  settings_screen.dart          User name, default role per baby,
                                caregiver list + add caregiver, backend note
  ui_helpers.dart               Time/duration formatting, colors

mobile/test/
  fairness_test.dart            20 tests (see Results)
  repository_test.dart          9 tests: seeding, connect-code
                                generate/find/regenerate/uniqueness,
                                entries CRUD, join-by-code, default role
  widget_test.dart              2 smoke tests: boots to Today with the
                                seeded baby; Settings shows Default role
```

Features from the spec that are in: per-baby connect code
(create shows it, join accepts it case-insensitively, detail screen
can copy/regenerate — regeneration invalidates the old code);
per-user default role (Settings, per baby, pre-selected in the log
form, per-entry override intact, clearable).

## Results (verbatim summaries)

`flutter analyze` — final run:

```
Analyzing mobile...
No issues found! (ran in 14.7s)
```

(First run had 3 issues — an unnecessary import and an invalid
`$` interpolation in a test regex; both fixed.)

`flutter test` — final run:

```
00:04 +31: All tests passed!
```

31 tests: fairness 20 (night-boundary splits at 22:00 and 06:00,
night 1.5x, pumping weight 1.5x, both multipliers stacking,
countsTowardBalance=false → 0, score formula incl. the 50-point
lopsided case, null score with one parent, outsourced share,
verdict thresholds, hourlyDominant, the Android app's own example:
pumping Mom 30 min = 45 pts vs supervising Dad 30 min = 21 pts),
repository/controller 9, widget 2.

## Interpretations of the Kotlin original (read before changing)

1. **"Breastfeeding/pumping 1.5x"** is not a special case in
   `Fairness.kt` — it is the *task weight* (1.5) in
   `defaultTasks()` in `Db.kt`. Only the night bonus (1.5, 22:00–
   06:00) is a hardcoded multiplier. Ported exactly that way.
2. **`splitDayNight` chunking:** Kotlin walks chunks aligned to
   *epoch* hour boundaries but classifies by *local* hour. For
   whole-hour timezone offsets (US Pacific included) these are the
   same boundaries; the Dart port walks local-hour boundaries.
3. **`hourlyDominant` with an entry before all `dayStarts`:**
   Kotlin would spin without advancing until its guard trips.
   The Dart port breaks out instead. No behavioural difference for
   real callers, which always pass covering day starts.
4. **`LogEntry.createdBy`** is new (the spec requires entries to
   carry their creator for sync); the Android model has no such
   field. Defaults to `''`.
5. Seed colors copied from `Db.ensureSeeded()`:
   Mom `0xFFE57373`, Dad `0xFF64B5F6`, baby `0xFFFFD54F`.

## What is stubbed / not yet ported

- **Firebase**: stub only (see header of
  `lib/firebase_repository_stub.dart` for the schema). Until it
  lands, data lives **only on the device running the app** — the
  two phones do not actually sync yet, and connect codes resolve
  locally on the device that created the baby. This is the mock
  the spec allows for this phase.
- Not ported from the Android app (yet): hourly logging reminders /
  notifications, CSV export, the Calendar tab and hourly heatmap
  *screen* (the `hourlyDominant` logic itself is ported and
  tested), the drag/resize Today timeline (the Flutter Today tab
  is a list + form), caregiver edit/delete beyond adding.

## Next steps — Firebase wiring (needs Pratik)

1. Pratik creates a Firebase project at
   console.firebase.google.com under his Google account (Spark /
   free tier), enables **Authentication** (email link or Google)
   and **Cloud Firestore**.
2. From a machine with the Firebase CLI: `flutterfire configure`
   in `mobile/` (or manually place the downloaded
   `google-services.json` in `mobile/android/app/` and
   `GoogleService-Info.plist` in `mobile/ios/Runner/`).
3. Add `firebase_core`, `cloud_firestore`, `firebase_auth` to
   `pubspec.yaml`, call `Firebase.initializeApp()` in `main()`.
4. Implement `FirebaseFairCareRepository` per the schema in the
   stub file and swap it for `LocalFairCareRepository` in
   `lib/main.dart` — no screen changes needed.
5. Write Firestore rules: a baby's subcollections are readable /
   writable only by uids in `babies/{id}.memberUids`; the
   top-level `connectCodes/{code}` doc is the only join path.
6. Move connect-code generation server-side (transaction or a
   small Cloud Function) so codes can't collide across users.

## Next steps — iOS on Akansha's Mac (free personal signing)

1. Clone the repo, install Flutter (docs.flutter.dev), then in
   `mobile/`: `flutter pub get`.
2. Open `mobile/ios/Runner.xcworkspace` in Xcode, select the
   Runner target → Signing & Capabilities → check "Automatically
   manage signing" and pick her personal team (Apple ID).
3. Connect her iPhone (trust the computer; on the phone:
   Settings → General → VPN & Device Management → trust the
   developer profile if prompted).
4. `flutter run --release` from `mobile/` (or Run in Xcode).
   Bundle id is `com.faircare.faircare`.
5. Free-signing limits apply: the install expires after **7 days**
   — reconnect and re-run to refresh. No push notifications /
   iCloud entitlements on a personal team.

## Next steps — Android build here

1. Install a JDK and the Android SDK on this VM (neither is
   present; `flutter doctor` will flag both), accept licenses
   with `flutter doctor --android-licenses`.
2. `cd mobile && flutter build apk --release` →
   `build/app/outputs/flutter-apk/app-release.apk`, sideload as
   before (install over the existing app; do not uninstall first
   if local data must survive — note the Flutter app's data is
   separate from the Kotlin app's).
3. Watch RAM: run the build serially and, if Gradle OOMs, cap its
   heap in `mobile/android/gradle.properties`
   (`org.gradle.jvmargs=-Xmx384m`), the same trick the manual
   Kotlin build in `../tools/build_apk.sh` uses on this VM.
