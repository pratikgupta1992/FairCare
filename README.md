# FairCare

A baby-care tracker for two parents: log who cared for the baby, hour by
hour, and see at a glance how fairly the work is being shared.

## Status

- `app/` — the current Android app (Kotlin / Jetpack Compose, local
  on-device data). This is the working reference build: hourly logging
  with an Outlook-style Today timeline, calendar views, fairness
  analytics (weighted minutes, night bonus, mom-only tasks like
  pumping counted fairly), CSV export, and logging reminders.
- [`COUPLES_SPEC.md`](COUPLES_SPEC.md) — the plan for the couples
  version: one cross-platform codebase for Android + iOS, a shared
  backend, a per-baby connect code to join a baby's log, and a
  per-user default role so logging pre-selects your caregiver
  (changeable on any entry).
- `mobile/` — the couples version in progress: one Flutter codebase
  for Android + iOS with the data model and fairness rules ported
  from the Android app, per-baby connect codes, and per-user default
  roles. Currently runs on a local mock backend; Firebase sync is
  next (see `mobile/BUILD_NOTES.md`).

## Building the Android app

The Android app builds with the manual pipeline in `tools/`:

```sh
tools/build_apk.sh
```

which produces `build-manual/FairCare.apk` (sideload install; data
stays on the phone).
