# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Inteli Rehab: a rehab system with four parts that share one Supabase project (Postgres + Auth + RLS):

| Dir | What | Stack |
|---|---|---|
| `firmware/` | Armband (ESP32): two MPU6500 IMUs (Madgwick fusion -> elbow angle) + EMG, streamed over BLE | Arduino/C++ (no build file checked in) |
| `Inteli_Rehab_Mobile_App/` | Patient app: onboarding, live exercise sessions from the band, progress, 3D digital twin | Flutter/Dart |
| `Intelli_Rehab_Web_Portal/` | Clinic admin + physiotherapist portal | React 19, Vite, Tailwind 4, Supabase (+ Deno edge functions) |
| `Inteli_Rehab_AI_Pipeline/` | Trains the elbow-rep autoencoder and exports it into the app | Python/PyTorch |

Other: `Model/` (source arm glTF), `docs/` (SRS, SDD, traceability matrix, PlantUML diagrams, `digital-twin-flow.md`), root `node_modules`/`package.json` (just `three`, used by the twin tooling). Code comments cite SDD sections and numbered "Rules" (e.g. "Rule 26" = offline-first sync); look them up in `docs/sdd` and `docs/srs`.

Note the directory spelling: `Inteli_...` (mobile, AI pipeline) vs `Intelli_...` (web portal).

## Commands

CI (`.github/workflows/`) is the source of truth; each job only runs when its directory changes.

**Mobile app** (`cd Inteli_Rehab_Mobile_App`; Flutter 3.47.5 in CI, Java 17):
```
flutter pub get
flutter analyze            # flutter_lints
flutter test               # all of test/
flutter test test/live_session_test.dart                 # one file
flutter test test/live_session_test.dart --plain-name "some test name"
flutter run
flutter build apk --release   # signed with debug key unless android/key.properties exists
flutter test test_live/onboarding_live_test.dart   # hits the LIVE Supabase project; creates then deletes a throwaway patient; deliberately outside `flutter test`
```
Override backend per build with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...` (defaults point at the production project in `lib/core/network/supabase_client.dart`). The app has no mock/offline-backend mode; `.vscode/launch.json` has a single "Mobile app" config.

**Web portal** (`cd Intelli_Rehab_Web_Portal`; Node 22):
```
npm ci
npm run dev
npm run lint               # oxlint (not eslint); config in .oxlintrc.json
npm test                   # vitest run (node env; component tests opt into jsdom via `// @vitest-environment jsdom`)
npx vitest run src/domain/physio/utils/sessionAnalytics.test.js   # one file
npx vitest run -t "test name"
npm run build
```
Needs `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` (in `.env`; `supabaseClient.js` throws at startup without them; CI uses placeholders). Deployed on Vercel; the CSP and security headers are in `vercel.json` and `public/_headers`, so any new external origin (media, fonts, API) must be added to the CSP.

**AI pipeline** (`cd Inteli_Rehab_AI_Pipeline`):
```
pip install -r requirements.txt
python -m unittest discover -s tests            # recording/segmenting tools
python src/elbow/export_to_app.py               # weights+thresholds -> mobile assets/ai/elbow_autoencoder.json
python src/elbow/make_golden_vectors.py         # -> mobile test/fixtures/elbow_golden.json
```
After retraining/recalibrating in `notebooks/train_elbow_model.ipynb`, run both scripts and then `flutter test` (`test/elbow_model_test.dart` proves the Dart copy matches PyTorch).

**Widget tests that save a session** (they go through `SessionJournal`, whose static lock keeps the first test's fake clock): at most ONE such test per test file, and give its real file writes time with `tester.runAsync` + `pump` in a loop (see `test/session_screen_extras_test.dart`). Use `--name <one-word>` to filter: a name with spaces or `|` breaks the Flutter launcher on Windows.

**Twin JS bundle** (only when `tool/twin_bundle/entry.js` or the Three.js version changes): `cd Inteli_Rehab_Mobile_App/tool/twin_bundle && npm install && npm run build` regenerates the committed `assets/twin/three_bundle.js`, so normal app builds never need Node.

## Architecture

### Database / backend
There is no server app. The schema, RLS policies and RPCs live as idempotent SQL scripts in `Intelli_Rehab_Web_Portal/scripts/supabase_*.sql`, run by hand in the Supabase SQL editor (`supabase_full_schema_snapshot.sql` documents the live schema; `supabase_setup.sql` is a destructive reset guarded against non-empty DBs). RLS is what actually enforces access for both clients, using helpers such as `is_admin_of_clinic` / `is_physio_of_patient`. Patient self-service goes through SECURITY DEFINER RPCs (`register_patient_self`, `choose_clinic_and_physio`, `delete_my_account`, ...). Privileged operations the browser can't do (creating physio auth users, physio sign-in by ID) are Deno edge functions in `Intelli_Rehab_Web_Portal/supabase/functions/`.

Physios can save the plan they are assigning as a clinic-wide template (`plan_templates`, `PlanTemplateUseCases`) and mark a patient recovered/reopened. SQL run order is in `Intelli_Rehab_Web_Portal/scripts/README.md` (a test fails if a script is added without being listed). Who counts as at risk is `riskAssessment.js` with the clinic's own thresholds (`clinics.risk_settings`, edited on the admin Clinic profile page); sending a warning stamps `patients.risk_reviewed_at`, after which only later sessions count, so the patient leaves the At Risk list. The portal refreshes on realtime changes to `sessions`/`patients` as well as every 60 s. Session-module migrations: `supabase_session_module_v2.sql` (per-set rows, `sessions.pain_level`/`ended_reason`, per-patient safety limits) and `supabase_warning_autoclear.sql` (warning erases after the patient's next session, with a log). Both clients tolerate them not being run yet (missing-column fallbacks), so keep that when adding columns the bulk session queries read.

When changing a table/column/RPC, check both clients: the portal (`src/infrastructure`, `src/domain/*/usecases`) and the app's repositories (`lib/features/*/*_repository.dart`). The SQL files were moved from the portal root into `scripts/` (uncommitted at the time of writing); docs, the app README and `generate_exercise_illustrations.py` (which writes `supabase_exercise_media.sql` there) now use the new location.

### Mobile app (`lib/`)
Feature-folder layout (`core/` + `features/{auth,onboarding,home,exercises,twin,progress,profile}`); no state-management package: `ChangeNotifier`s, repositories that call Supabase directly, and `AuthGate` in `lib/app.dart` as the root router. `AuthGate` re-resolves on every auth change: no session -> welcome; no `patients` row -> finish `register_patient_self()` from answers stashed in auth metadata (email-confirmation case); no clinic chosen -> onboarding resumed at step 4; not approved -> waiting screen; approved -> `HomeShell`. Physio approval happens in the portal.

The live-session path spans many files:
1. `features/home/ble/` — `ArmBandBleService` (flutter_blue_plus) scans for the advertised name `ArmEMG-IMU` and subscribes to the data characteristic; `arm_band_protocol.dart` mirrors the firmware GATT UUIDs and the packed 8-byte little-endian packet (`elbowDeg`, `emg1Pct` as float32, ~31 Hz; the old 16-byte packet is still accepted). One-byte commands `g`/`z`/`m` (gyro recalibrate / zero pose / MVC calibration) are written to the command characteristic. **Any change to the packet or UUIDs must be made in `firmware/lib/ArmEMG_IMU/BLEStreamer.*` and `arm_band_protocol.dart` together.** `WearableConnectionController` owns connection state and exposes `liveSamples`.
2. `features/exercises/live_session.dart` — `LiveSession` implements `SessionController` (the interface the Active Session screen uses; `SessionSimulator` is the timer-driven stand-in for tests/demos). It counts reps from angle "hills", and combines three feedback tiers from `processing/`: green (fine), amber (`ElbowRepChecker`/`ElbowAutoencoder` model score after the rep, falling back to simple `RepAssessor` rules if the model isn't loaded), red (`SafetyMonitor` live angle/speed limits, pauses the session). Also `FatigueEstimator`, `EmgProcessor`. The angle is relative to the band's zero pose, which must be set before starting.
   A session is `sets` x `repsTarget` reps: `LiveSession.repsTarget` is the whole-session total, `repsPerSet` the per-set count, and between sets it pauses in a rest (`isResting`; the screen's `_RestCard` counts down and calls `endRest()`). ROM% is measured against the patient's calibrated peak flexion (`SessionSetup`, loaded in `ExerciseDetailScreen` before the session starts), but the red angle limit never drops below the anatomical default, so recovering past the baseline is not "unsafe". `patients.safety_max_*` (set per patient in the portal's `SafetyLimitsCard`) overrides the red limits. Rest between sets is per exercise (`patient_exercise_plans.rest_seconds`, set in the portal's assign form, default 30 s); the patient's range and limits are cached on the phone (`SessionSetupCache`) so an offline start keeps the physio's limits. "This hurts" and the end-of-session pain/reason question are saved on the session. `SessionCues` speaks cues through `DeviceServices` (Android `TextToSpeech`, `FLAG_KEEP_SCREEN_ON`, both in `MainActivity.kt`, no plugins).
   The Exercises tab's "Start today's workout" runs the whole plan through `WorkoutFlowScreen`: each exercise is still its own `ActiveSessionScreen` session (opened with `returnOutcome: true` so it hands its `SessionOutcome` back instead of showing its own summary), with one `WorkoutSummaryScreen` at the end. The daily exercise reminder (`features/reminders/`, `Reminders.kt`: AlarmManager + a notification, no plugin) fires only when a session is due under the plan's frequency and none was done since.
3. `features/exercises/session_journal.dart` — offline-first persistence: in-progress session rewritten after every rep, finished sessions queued in `pending` until uploaded (idempotent via client-generated ids), permanently rejected ones moved to `failed` (never deleted). Corrupt journal files are renamed aside, never overwritten.
4. `features/twin/` — the live 3D arm is a Three.js scene (`assets/twin/twin.js` + generated `three_bundle.js`) in a WebView served from a loopback `HttpServer` (`TwinAssetServer`, plain HTTP to 127.0.0.1 allowed by the Android network-security config); `TwinBridge` sends throttled JS calls down and receives `ready`/`error` over a JS channel; a 2D `LiveDigitalTwin` is the fallback. Full walkthrough: `docs/digital-twin-flow.md`.

The elbow model runs in plain Dart (no ML plugin) from weights in `assets/ai/elbow_autoencoder.json`; that file and `test/fixtures/elbow_golden.json` are generated by the AI pipeline, don't hand-edit. Thresholds/tolerance come from Kinect data and are not yet validated on armband data; `SafetyLimits` red thresholds are placeholders (see `Inteli_Rehab_AI_Pipeline/README.md`, which has the details on states, modes and recording tools).

### Web portal (`src/`)
Layered as `domain/` (hooks, use cases, entities, pure analytics/risk utils — most of the tests), `infrastructure/` (Supabase client, repositories, constants/theme), `presentation/` (pages, shells, components). Two role-specific areas share the app: `presentation/admin` + `domain/admin` (clinic admin: physiotherapists, patients, clinic profile) and `presentation/physio` + `domain/physio` (dashboard, patients, approvals, at-risk, exercises, session replay). Routing is hash-based (`useHashRoute`: `#/login`, `#/app/patients/<id>`), with `App.jsx` choosing the admin or physio shell from `authRole` (set in `domain/admin/useAuth.js`: tries physio, then clinic admin via `clinics.admin_user_id`). Shells and pages are `React.lazy` chunks; keep it that way so recharts and the other role's code stay out of the wrong bundle. `App.jsx` polls patients (60 s) and wearable presence (15 s).

Exercise illustrations are generated by `scripts/generate_exercise_illustrations.py` and consumed by both the portal and `Inteli_Rehab_Mobile_App/assets/exercises/`; `data/exercises.csv` is the exercise catalogue source.

### Firmware
The real firmware is the Arduino sketch in `firmware/lib/ArmEMG_IMU/` (`ArmEMG_IMU.ino`, `BLEStreamer`, `MPU6500`, `MadgwickAHRS`, `EMGProcessor`); the app and AI-pipeline comments point there. `firmware/src/` (`ble/`, `sensors/`, `calibration/`, `power/`, `main.cpp`) is a skeleton of empty 0-byte files, so don't look for logic in it. There is no PlatformIO/Arduino build config; the sketch is built from the Arduino IDE.
