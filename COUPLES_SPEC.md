# FairCare — Couples Version Spec

Decided 2026-10-21 with Pratik.

## Goal
One real app Pratik (Android) and Akansha (iPhone) both use to log care
for the same baby, with the existing fairness analytics. No $99/yr Apple
Developer fee for now.

## Repo / codebase
- Single GitHub repo: https://github.com/pratikgupta1992/FairCare
- Single cross-platform codebase — NOT separate Android and iOS apps.
  One UI + one logic codebase that compiles to both an Android APK and
  an iOS app, so a fix or feature lands on both phones at once.
- The existing Kotlin Android app in this folder is the reference for
  features, data model, and fairness rules until the cross-platform
  build reaches parity.
- iOS builds happen on Akansha's Mac via Xcode with free personal
  signing (Apple ID personal team). Known free-signing limits:
  build expires after 7 days and must be re-installed from Xcode,
  some capabilities (push, iCloud) are restricted. TestFlight / $99
  stays the later upgrade path if the weekly re-install gets annoying.
- Android builds here / in CI, sideloaded APK, no expiry.

## Sharing model — per-baby connect code (REQUIRED)
- Every baby profile gets a short connect code (generated server-side,
  shown in the baby's settings/share screen, regenerable, revocable).
- Another user enters the code in "Join a baby" to get access to that
  baby's log — no other route in.
- A user can belong to multiple babies; codes are per baby, not per user.
- Roles/access are granted per baby via the code join.

## Default role per user (REQUIRED)
- Each user picks a default caregiver/role for themselves per baby
  (e.g. Pratik = Dad, Akansha = Mom).
- The log-care form pre-selects that default every time, so the common
  case is zero extra taps.
- The caregiver can still be changed on any individual entry
  (logging on someone else's behalf stays possible).

## Sync — Firebase (decided 2026-10-21)
- Backend is Firebase (Auth + Firestore, free Spark tier), NOT
  Cloudflare. Rationale: Firestore gives realtime sync and offline
  persistence out of the box in the Flutter SDK, and Firebase Auth
  covers sign-in — a Cloudflare Workers/D1 backend would mean
  hand-rolling sync, offline queuing, conflict handling, and auth
  for a two-user app. Cloudflare stays an option for static hosting
  (landing/privacy page) later.
- Both phones read/write the same log entries, caregivers, and tasks
  for a joined baby.
- Entries carry created-by user, timestamps; edits and deletes
  propagate to both phones.
- Setup still needed: a Firebase project under Pratik's Google
  account (he creates it / signs in; config files then land in the
  repo). Until then the app runs against a local mock backend behind
  the same repository interface.

## Data model carried over from the Android app
Baby, Caregiver (type: Mom/Dad/Parent/Nanny/Daycare/Family),
CareTask (weight, eligibility e.g. Mom-only, counts-toward-balance),
LogEntry (baby, caregiver, task, start, end, note).
Fairness rules live in logic/Fairness.kt in the Android app and must
be ported unchanged in behaviour.
