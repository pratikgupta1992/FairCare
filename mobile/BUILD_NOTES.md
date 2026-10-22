# FairCare — Cross-Platform Scaffold Build Notes

Built 2026-10-21 (scaffold phase). The Android Kotlin app at the repo
root was used read-only as the reference and was not modified.

---

## 2026-10-21 (later) — Firebase wiring

### What changed

- **Dependencies** (via `flutter pub add`): `firebase_core ^5.0.0`,
  `firebase_auth ^7.0.0`, `cloud_firestore ^7.0.0`.
- **`lib/firebase_repository.dart`** — NEW, real implementation;
  `lib/firebase_repository_stub.dart` is **deleted**. 
  `FirestoreFairCareRepository` implements the same
  `FairCareRepository` interface against this schema:
  `babies/{id}` {name, color, connectCode, memberUids, createdBy,
  createdAt, updatedAt}; `babies/{id}/caregivers|tasks|entries`
  subcollections (model codecs from `models.dart`; entries also
  carry createdBy = uid and server timestamps); top-level
  `connectCodes/{CODE}` → {babyId} for join-by-code (joining
  arrayUnion's the caller's uid into memberUids).
  Design notes:
  - The interface stayed synchronous/cache-backed: `init()` does a
    one-shot load, then Firestore snapshot listeners keep the
    caches live and emit on the new `changes` stream — that stream
    is the realtime path (partner's entry → snapshot → cache →
    controller rebuild). One-shot reads are used only for the
    initial load and inside `joinWithCode` (lookup + post-join
    load); everything else is listener-fed.
  - Int model ids double as Firestore doc ids (as strings); new
    ids are epoch-millis. Each baby seeds caregivers Mom=1/Dad=2
    and tasks 1–12, exactly like the local backend.
  - Interface adaptations (the only ones): `babyForCode` (sync)
    → `Future<Baby?> joinWithCode` (joining is a network op), and
    the added `changes` stream. Local repository, controller and
    tests adapted accordingly.
  - `addCaregiver`/`addTask` have no baby parameter in the
    interface, so Firestore writes them into every joined baby
    (same id) — documented in the file header.
  - `createBaby` writes the baby doc FIRST, then batches the rest:
    the security rules check membership via `get()`, which sees
    pre-batch state.
- **`lib/firebase_options.dart`** — config drop point with clearly
  marked `REPLACE_ME` placeholder values. No real config exists
  yet; analyze/tests pass with placeholders.
- **`lib/auth_service.dart`** — `AuthService` abstraction +
  `FirebaseAuthService` (email/password sign-in, sign-up, sign-out,
  authState stream) + parent-friendly error messages.
  **`lib/auth_screen.dart`** — sign-in/sign-up screen.
- **`lib/main.dart`** — backend switch
  `--dart-define=USE_LOCAL_BACKEND=true` runs the local mock with
  NO Firebase config (tests + pre-config demos). Default mode
  initialises Firebase and runs `FirebaseFairCareRoot`: auth gate
  (signed-out → AuthScreen; signed-in → per-uid Firestore repo +
  controller, loading spinner meanwhile). If Firebase init throws
  (placeholders / missing google-services.json on a fresh
  checkout), the app falls back to the local backend instead of
  crashing. Settings now shows the real backend label, the
  signed-in account, and a sign-out button in Firebase mode.
- **`lib/onboarding_screen.dart`** — first-run flow, one screen:
  (1) your name, (2) "Create our baby" (shows the connect code big
  with copy + "share this with your partner") OR "Join with a
  code", (3) default-role chips (Mom/Dad/Parent), then "Start
  logging care". `FairCareApp` routes users with no baby to it;
  users with a baby skip straight to Today.
- **`firestore.rules`** (project root) — authenticated-only;
  babies + subcollections readable/writable only by memberUids;
  connectCodes: `get` by any signed-in user (the code is the
  secret), no listing, create/delete only by members of the baby
  it points to; the baby-doc update rule additionally allows the
  join write (a non-member appending ONLY their own uid to
  memberUids). Header says it plainly: **deploy manually** —
  Firebase Console → Firestore → Rules → paste → Publish (or
  `firebase deploy --only firestore:rules`). Do this BEFORE real
  use; until published, console default rules apply.
- **Android**: google-services Gradle plugin wired
  (`com.google.gms.google-services` 4.4.3 in
  `android/settings.gradle.kts` `apply false`, applied in
  `android/app/build.gradle.kts`). `google-services.json` is
  intentionally absent — an Android *device build* will fail
  until it lands; analyze/tests are unaffected.
- **iOS**: `GoogleService-Info.plist` goes in `ios/Runner/` (add
  it to the Runner target in Xcode). Not fabricated; absent for
  now.

### Results

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! — 34 tests**: the existing
  31 (fairness 20, repository/controller 9 — join tests updated
  for the async `joinWithCode` — widget 2) plus 3 new in
  `test/firebase_mode_test.dart`: connect-code normalization,
  auth gate shows sign-in when signed out (fake AuthService —
  Firebase untouched), and the full onboarding flow in local mode
  (create baby → code shown → pick Dad → lands on Today).
  The Firestore join path itself is NOT unit-tested — it needs a
  real project; don't fake it.

### Remaining steps, in order

1. **Drop the real config.** With the Firebase CLI signed in to
   Pratik's Google account: `cd mobile && flutterfire configure`
   (creates `lib/firebase_options.dart` for real, drops
   `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`). In Firebase Console,
   first enable **Authentication → Email/Password** and create the
   **Firestore** database.
2. **Publish the rules**: paste `mobile/firestore.rules` into
   Firebase Console → Firestore Database → Rules → Publish.
3. **Android build** (this VM or any machine): install JDK +
   Android SDK, `flutter doctor --android-licenses`, then
   `cd mobile && flutter build apk --release` (cap Gradle heap
   `-Xmx384m` in `android/gradle.properties` if it OOMs on this
   VM). Sideload the APK.
4. **Akansha's Mac**: clone repo → `flutter pub get` → open
   `ios/Runner.xcworkspace`, add `GoogleService-Info.plist` to
   the Runner target, set her personal team under Signing &
   Capabilities → connect iPhone → `flutter run --release`.
   Free-signing rules still apply (7-day expiry, re-run to
   refresh).
5. First real run-through: Pratik creates the account + baby,
   shares the code; Akansha signs up, joins with the code, both
   log an entry and watch it appear on the other phone.

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

- **Firebase**: ~~stub only~~ — SUPERSEDED by the "Firebase
  wiring" section at the top of this file: the real Firestore
  repository, auth gate, and onboarding are implemented. Sync is
  live once the real config is dropped in and the rules are
  published (steps 1–2 there). Until then the app still defaults
  to device-local data in local mode / fallback.
- Not ported from the Android app (yet): hourly logging reminders /
  notifications, CSV export, the Calendar tab and hourly heatmap
  *screen* (the `hourlyDominant` logic itself is ported and
  tested), the drag/resize Today timeline (the Flutter Today tab
  is a list + form), caregiver edit/delete beyond adding.

## Next steps — Firebase wiring (needs Pratik)

SUPERSEDED — see "Remaining steps, in order" in the Firebase
wiring section at the top. (One item from this original list
remains a future hardening step: moving connect-code generation
fully server-side via a transaction/Cloud Function. The current
implementation verifies codes against the `connectCodes`
collection before using one, which is sufficient at family
scale.)

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

## 2026-10-21 (evening) — Real Firebase config wired

- The Firebase project now EXISTS — created by the project owner
  in his own browser (Muse's browser sign-ins were hard-blocked
  by Google twice). Project: **faircare-9c88f**, project number
  **414814305942**, storage bucket
  `faircare-9c88f.firebasestorage.app`, free Spark plan.
- All values were sourced from the owner's own uploaded config
  files (`google-services.json` and `GoogleService-Info.plist`,
  downloaded by him from the Firebase Console) — not from chat
  transcription.
- `lib/firebase_options.dart`: Android and iOS `FirebaseOptions`
  now hold the real values (Android appId
  `1:414814305942:android:258d045731c5ca46530cb7`, iOS appId
  `1:414814305942:ios:d8e56fbbd52d6017530cb7`, both package/bundle
  `com.faircare.faircare`). No more REPLACE_ME placeholders on
  Android/iOS. Web options remain placeholders — web is not a
  registered platform; do not invent values for it.
- Platform files placed as exact byte copies (md5-verified
  against the uploads):
  `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist`.
- Android Gradle wiring confirmed (Kotlin DSL): settings declares
  `com.google.gms.google-services` 4.4.3, `android/app` applies
  it, `applicationId = "com.faircare.faircare"`.
- ⚠️ iOS follow-up: `ios/Runner.xcodeproj/project.pbxproj` does
  NOT reference `GoogleService-Info.plist` — the file is on disk
  but Xcode won't bundle it until it's added to the Runner target.
  Fix on Akansha's Mac: open the workspace in Xcode, drag
  `GoogleService-Info.plist` into the Runner group, ensure the
  Runner target is checked (or run `flutterfire configure` there).
  Until then, Firebase init on a real iOS device will fail even
  though analyze/tests pass.
- Verification after wiring: `flutter analyze` — no issues.
  `flutter test` — **34/34 passed**.
- Still owner-side in the Console (per the Gemini setup sheet):
  Firestore created in production mode (US), `firestore.rules`
  published, Email/Password provider enabled. Config drop-in is
  done regardless; the app falls back to the local backend if
  Firebase init fails.

## 2026-10-21 (late) — App identity: "FairCare" name + family icon, parents' features darkened

Pratik installed the couples build and found it showed as lowercase
"faircare" with the default Flutter logo. Fixed name + icon, and per
his instruction darkened the parents' facial features in the icon.

- **Source artwork:** the original AI-generated master at
  `icon-work/media-generation-faircare-family-icon-soft-0-ec618659-234c-448b-91ca-851934ada5a4.webp`
  (1600×1600, the "soft" color version). Verified it is the exact
  source of the old native app's launcher foreground (downscale diff
  0.0 vs `app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png`,
  432×432). Original left untouched.
- **Eye/feature edit:** the parents' closed-eye curves and smiles were
  rendered in pale cream (254,242,216) on peach skin (250,206,182) —
  sampled and confirmed. On a copy of the master, pixels matching that
  cream inside the two parent-face ellipses (baby region excluded)
  were blended to warm dark brown (107,66,50) #6B4232, weighted by
  distance-to-feature-color so anti-aliased edges blend naturally;
  a second targeted pass (rect x 612–672, y 830–892) caught the tip
  of Mom's right-eye stroke that the baby-exclusion zone had clipped.
  ~16,975 px changed; verified 0 changes to the baby's face (dark
  teal eyes (1,79,101), cream skin, rose blush all byte-identical),
  the teal background, hearts, or skin tones.
- **Files changed:**
  - `android/app/src/main/AndroidManifest.xml` — label "faircare" → "FairCare".
  - `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
    — regenerated from the edited artwork (48/72/96/144/192 px).
  - `assets/icon/icon.png` — edited master copy, 1024×1024 (new).
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` — full set
    regenerated from the edited artwork; Contents.json filenames unchanged.
  - `ios/Runner/Info.plist` — CFBundleDisplayName "Faircare" → "FairCare",
    CFBundleName "faircare" → "FairCare".
- **Verification:** `flutter analyze` — no issues. `flutter test` —
  **34/34 passed**. Release rebuild succeeded (~5.8 min).
  `aapt2 dump badging`: `application-label:'FairCare'` (all locales),
  package `com.faircare.faircare` v1.0.0. The APK's embedded icon
  resource is pixel-identical (mean abs diff 0.0 at 48×48) to the
  edited master.
- **APK:** `build/app/outputs/flutter-apk/app-release.apk`,
  55,383,686 bytes; copy saved as `build-manual/FairCare-couples.apk`.
