# Inteli Rehab — Patient Mobile App

Flutter app for patients (FR-1: Patient Registration and Login). Talks to the
same Supabase project as `Intelli_Rehab_Web_Portal`.

## What's here

- `lib/core/network/supabase_client.dart` — Supabase init, same project as the web portal
- `lib/core/models/patient_profile.dart` — maps a `patients` row
- `lib/features/auth/` — sign in, and the `AuthService` wrapper around Supabase calls
- `lib/features/onboarding/register_screen.dart` — registration ID + email/password
- `lib/features/home/` — pending-approval screen and a placeholder home screen
- `lib/app.dart` — `AuthGate`: routes between login → pending → home based on
  session + `patients.approved`

## How registration actually works

A patient can't just sign up out of nowhere — a physio creates their
`patients` row first (name, injury, clinic, and a `reg_id`), then hands the
patient that registration ID. The patient enters it once in this app's
Register screen, which:

1. Calls `supabase.auth.signUp()` to create their login
2. Calls the `claim_patient_record(reg_id)` RPC (see
   `Intelli_Rehab_Web_Portal/supabase_patient_self_registration.sql`) to link
   that login to the physio-created row

They then land on the pending-approval screen until a physio approves them —
the same `ApprovalsPage.jsx` flow already built in the web portal.

## What's NOT here yet

- **No way to actually generate a `reg_id` for a real patient.** The web
  portal has no "Add Patient" UI (only `PatientUseCases.getAllPatients()` —
  read-only). Nothing end-to-end testable exists until that's built, mirroring
  `AddPhysiotherapistModal.jsx` but for patients.
- Android/iOS/etc. platform folders. This was hand-authored without the
  Flutter SDK available in this environment — run `flutter create .` from
  this directory once Flutter is installed locally; it fills in the missing
  platform scaffolding without touching `lib/` or `pubspec.yaml` since those
  already exist.
- Everything past FR-1: wearable pairing, session tracking, digital twin,
  AI feedback, offline sync (FR-7 through FR-19).

## Running it

```
flutter create .        # generates android/, ios/, etc. — one-time
flutter pub get
flutter analyze         # this repo has NOT been run through analyze yet — expect to fix something
flutter run
```

**Important:** none of this Dart code has been compiled, analyzed, or run —
the Flutter/Dart SDK isn't available in the environment it was written in.
Treat it as a structural first draft, not verified working code. Run
`flutter analyze` before trusting it.
