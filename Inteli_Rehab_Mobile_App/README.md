# Inteli Rehab — Patient Mobile App

Flutter app for patients: self-registration, onboarding and (later) rehab
session tracking. Talks to the same Supabase project as
`Intelli_Rehab_Web_Portal`, and uses the portal's colours and logo.

## What's here

- `lib/app.dart` — `AuthGate`: routes a user to welcome, onboarding (resumed),
  waiting-for-approval or home, based on their session and `patients` row
- `lib/core/theme/` — portal colour tokens, light/dark themes, the app-wide theme toggle
- `lib/features/onboarding/` — welcome screen and the 7-step onboarding flow
  - `onboarding_repository.dart` — every Supabase call onboarding makes
- `lib/features/auth/` — sign in, `AuthService`
- `lib/features/home/` — placeholder home screen for approved patients

## How sign-up works

Patients create their own account — no clinic-issued ID needed.

| Step | Saved to |
| --- | --- |
| 1 Personal details, 2 Injury details, 3 Contact | `auth.signUp` then `register_patient_self()` → `patients` + `patient_injuries` |
| 4 Clinic / physiotherapist | `list_onboarding_clinics()`, `list_clinic_physiotherapists()`, `choose_clinic_and_physio()` → `patients.clinic_id`, `physio_id` |
| 5 Wearable | `wearable_devices` (`status = 'paired'`; earlier bands → `'replaced'`) |
| 6 Calibration | `sessions` (rom = range, no exercise) + `movement_analysis` (`posture_status = 'baseline_calibration'`) |
| 7 Wait for physiotherapist | reads `patients.approved`; the physio approves in the portal |

If the Supabase project requires email confirmation, sign-up returns no
session. The answers are saved in the auth user's metadata, and `AuthGate`
finishes `register_patient_self()` on the first sign-in, then resumes at step 4.
Once the account exists, steps 1–3 are locked; leaving signs out, and the
patient resumes where they left off next time.

### Database migrations this needs

Run in the Supabase SQL editor, in this order (all idempotent), from
`Intelli_Rehab_Web_Portal/`:

1. `supabase_patient_onboarding.sql`
2. `supabase_patient_onboarding_v2.sql`
3. `supabase_patient_choose_clinic_physio.sql`
4. `supabase_patient_wearable_sync.sql` — keeps `patients.wearable_connected` in sync for the portal
5. `supabase_patient_delete_account.sql` (not used by the app yet)

## Not built yet

- Real Bluetooth: the wearable scan/connect and the calibration readings are
  simulated (`mock_directory.dart`); the chosen band and baseline *are* saved.
- Everything after approval: sessions, exercise plans, progress, offline sync.

## Running it

```
flutter pub get
flutter analyze
flutter test
flutter run
```
