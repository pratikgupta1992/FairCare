# FairCare on iPhone — run it on Akansha's phone (free, no $99 account)

FairCare is one Flutter codebase. The iPhone build happens on a Mac
with Xcode, signed with a free Apple ID "Personal Team". No Apple
Developer Program membership is needed for personal use.

## What you need

- A Mac with Xcode installed (App Store, free) and signed in to an
  Apple ID in Xcode → Settings → Accounts.
- The iPhone, unlocked, with a cable (or Wi-Fi pairing set up in
  Xcode → Window → Devices and Simulators).
- The Firebase config file `GoogleService-Info.plist` — Muse drops
  this into the repo once the Firebase project exists. If it's
  missing, the app still runs in local demo mode but the two phones
  will NOT sync.

## Steps

1. Clone the repo:
   `git clone https://github.com/pratikgupta1992/FairCare.git`
2. Install Flutter if needed (https://docs.flutter.dev/get-started/install/macos),
   then in the repo: `cd FairCare/mobile && flutter pub get`
3. Make sure `ios/Runner/GoogleService-Info.plist` exists (it is now
   in the repo — real config, added 2026-10-21).
   ⚠️ IMPORTANT: the file existing on disk is NOT enough — the Xcode
   project does not reference it yet. After opening the workspace
   (step 5), drag `GoogleService-Info.plist` from the `ios/Runner`
   folder into the **Runner** group in Xcode's left sidebar, and in
   the dialog make sure the **Runner target** is ticked. Without this
   step the app builds but Firebase fails to start on the phone.
4. App icon: the repo cannot carry the PNG icon files, so Muse will
   send the master `icon.png` (the family logo, parents' eyes darkened)
   separately. In Xcode, open `Assets.xcassets` → `AppIcon` and drag
   the 1024×1024 `icon.png` into the icon well — one size is enough.
5. Open `ios/Runner.xcworkspace` in Xcode (**xcworkspace**, not the
   xcodeproj).
6. Select the **Runner** target → Signing & Capabilities:
   - Tick "Automatically manage signing".
   - Team: choose your **Personal Team** (your Apple ID).
   - If Xcode complains the bundle ID is taken, change it to
     something personal, e.g. `com.faircare.faircare.akansha` —
     tell Muse, the Firebase iOS app must be re-registered with
     the same ID.
7. Pick your iPhone as the run destination (top toolbar), press
   **Run ▶**.
8. First launch only: on the iPhone go to Settings → General →
   VPN & Device Management → trust your Apple ID developer profile.
9. In the app: create your account (email + password), then either
   join with the baby's connect code (Babies → Join) or create the
   baby and share its code. Set your default role in Settings so
   logging pre-selects you.

## The free-signing catch (expected, not a bug)

- The app **expires 7 days** after each Xcode run. When it stops
  opening, plug the phone back in and press Run again — data is in
  Firebase, nothing is lost.
- A free Personal Team can only have a few app IDs/profiles at
  once; if Xcode errors about that, delete an old personal project
  profile and retry.
- Push notifications are restricted under free signing; FairCare's
  in-app logging and sync don't need them.

## If we outgrow this

A $99/yr Apple Developer account turns this into TestFlight builds:
no 7-day expiry, over-the-air updates. The code doesn't change —
only the signing/distribution step.
