# INTELI-REHAB — Requirements Traceability Matrix

**Status:** Reconciled version. Supersedes SDD Table 7.1, which uses a different
(unreconciled) FR numbering scheme — see "Reconciliation Notes" at the bottom.

**Canonical source of FR numbering:** SRS, Functional Requirements section (FR-1–FR-19).
**Canonical source of UC numbering:** SRS, Use Case Description section (UC-1–UC-19).

This matrix is a living document. Update the **Status** column as work lands —
don't let it drift out of sync with the codebase the way the SDD's copy did.

## Layered Architecture Map (SDD §3.1)

Where each of the SDD's seven layers actually lives, so "does the code follow
the architecture" has one place to check instead of being re-derived per FR.

| Layer (SDD §) | What it does | Where it lives |
|---|---|---|
| 3.1.1 Perception / Sensing | Dual IMU (upper arm + forearm) + EMG electrodes, BLE firmware | `firmware/lib/{MPU6500,MadgwickAHRS,EMGProcessor}.*`, `firmware/src/sensors/` — separate repo layer, not app code |
| 3.1.2 Communication | BLE pairing, streaming, calibration handshake | `Inteli_Rehab_Mobile_App/lib/features/home/wearable_connection_controller.dart`, `lib/features/home/bluetooth_rationale.dart` (Rule 23's in-context permission ask), `lib/features/onboarding/steps/wearable_setup_step.dart`. No BLE plugin wired yet — simulated pairing against `wearable_devices`; `firmware/src/ble/ble_server.*` is the device-side half this will eventually talk to |
| 3.1.3 Intelligence & Processing | Sensor Fusion, EMG Processor, AI Engine, Digital Twin | `lib/features/exercises/processing/{sensor_fusion,emg_processor,ai_engine}.dart` — split into three named classes so each is independently testable (`test/processing_layer_test.dart`) and swappable for a real model without touching the orchestrator. `SessionSimulator` (`lib/features/exercises/session_simulator.dart`) composes the three per tick; all simulated pending FR-7/FR-8/real AI. Digital Twin: `lib/features/home/widgets/{digital_twin_card,static_joint_pose}.dart` (static, Home) and `lib/features/exercises/widgets/live_digital_twin.dart` (live, colour-coded by AiEngine's tier, Active Session) |
| 3.1.4 Application | Flutter mobile app: onboarding, pairing, live exercises, progress, gamification | `Inteli_Rehab_Mobile_App/lib/features/{onboarding,home,exercises,progress,profile}/` |
| 3.1.5 Data & Sync | Local cache + offline-first cloud sync | `lib/features/exercises/session_journal.dart` — in-progress sessions are journalled to disk every rep (survives backgrounding/process death, Rules 22/27) and finished sessions queue for upload when saving fails, synced idempotently (`ExercisesRepository.saveSession`'s `upsert(..., ignoreDuplicates: true)` on client-generated ids) so a retry can never duplicate a row |
| 3.1.6 Cloud & Infrastructure | Supabase: auth, database, realtime | `Inteli_Rehab_Mobile_App/lib/core/network/supabase_client.dart` and `Intelli_Rehab_Web_Portal/src/infrastructure/supabase/supabaseClient.js` point at the same project; every table gated by the RLS policies in `Intelli_Rehab_Web_Portal/scripts/supabase_*.sql` — that's what actually enforces layer boundaries on data access, not just app-side convention |
| 3.1.7 Presentation / Monitoring | Physiotherapist & clinic admin web dashboard | `Intelli_Rehab_Web_Portal/src/presentation/{physio,admin}/` — reads/writes Cloud layer only, no sensor processing or session logic of its own (`src/domain/*/usecases` are view-model aggregation over already-processed rows, e.g. `sessionAnalytics.js`'s streak/weekly-ROM math) |
| 3.1.8 AI Training Pipeline | Offline Python training on EMG datasets, exported to the app | `Inteli_Rehab_AI_Pipeline/` — separate repo, not started (only `requirements.txt.txt` exists); `AiEngine`'s doc comment (`lib/features/exercises/processing/ai_engine.dart`) is the seam where its exported model would plug in |

Inter-layer relationships (SDD §3.1.9), as implemented:
- Wearable → Mobile App: not real yet — `WearableConnectionController` simulates what `firmware/src/ble` would stream.
- Mobile App → AI Engine: `SessionSimulator` calls `AiEngine.assessRep()` once per completed rep.
- AI results → Live 3D model + alerts: `AiEngine`'s `RepAssessment` feeds `LiveDigitalTwin`'s colour *and* the `alerts` list in the same call — see `RepAssessment`'s doc comment.
- App saves data → Local storage → Cloud: `SessionJournal` (local) → `ExercisesRepository.saveSession` (cloud), offline-first per FR-19.
- Cloud feeds → Web dashboards: `Intelli_Rehab_Web_Portal`'s `usecases/*` read the same tables the mobile app writes.
- Training updates models → Mobile App: not built — no export/import path exists between `Inteli_Rehab_AI_Pipeline` and `AiEngine` yet.

| FR ID | Title | Priority | Correct UC Source(s) | Design Component (SDD) | Repo Location | Status |
|---|---|---|---|---|---|---|
| FR-1 | Patient Registration and Login | High | UC-1 | `Patient`/`User` class, `OnboardingController`, `AuthService.login()` | `Inteli_Rehab_Mobile_App/lib/features/auth/`, `lib/features/onboarding/`, `Intelli_Rehab_Web_Portal/scripts/supabase_patient_onboarding*.sql`, `supabase_patient_self_registration.sql` | Implemented — 6-step onboarding, sign-up/sign-in, email-confirmation resume, and clinic/physio choice all live end to end; widget-tested (`test/onboarding_flow_test.dart`) |
| FR-2 | Role-Based Authentication | High | UC-1, UC-17, UC-19 | `AuthService`, role-based route guard | `Inteli_Rehab_Mobile_App/lib/features/auth/auth_service.dart`, `Intelli_Rehab_Web_Portal/src/domain/admin/useAuth.js`, `backend/supabase` (RLS policies) | In Progress — physio/admin login + RLS working in `Intelli_Rehab_Web_Portal`; patient-facing auth now also live in the mobile app (`AuthGate` in `lib/app.dart` routes by `patients.approved`/`clinic_id`) |
| FR-3 | Patient Rehabilitation Profile Management | High | **⚠ GAP — no UC covers this** | `PATIENT`, `INJURY` entities only (ER diagram); no class/method or UI flow documented | `Inteli_Rehab_Mobile_App/lib/features/profile/` (`profile_screen.dart`, `edit_personal_info_screen.dart`, `change_password_screen.dart`), `Intelli_Rehab_Web_Portal/scripts/supabase_patient_profile_self_edit.sql` | Implemented — see note 6. Built strictly from existing `PATIENT`/`WEARABLE_DEVICE` fields (no UC to build past) rather than left blocked; note 1's UC-numbering gap is still an open documentation issue, just no longer a code blocker |
| FR-4 | Rehabilitation Exercise Database | High | UC-12 | `Exercise` class, `ExerciseRepository` | `Intelli_Rehab_Web_Portal/src/{infrastructure/physio/repositories/ExerciseRepository.js,presentation/physio/pages/ExercisesPage.jsx}`, `supabase_seed_exercises.sql` | Implemented — the physio Exercise Database tab and the assign-session picker (FR-5) both read the real `exercises` table now; the mock array (`constants/mockData.js`) is deleted |
| FR-5 | Personalized Exercise Plan Management | High | UC-13, UC-14, UC-16 | `ExerciseProtocol` class, `assign()` method | `Intelli_Rehab_Web_Portal/src/domain/physio/usecases/ExercisePlanUseCases.js` (`assignSession()`, physio-side), `Inteli_Rehab_Mobile_App/lib/features/exercises/{plan_list_screen,exercises_repository}.dart` (patient-side) | Implemented — a physio picks a patient (`PatientsPage.jsx`'s "Assign exercise" modal), selects one or more exercises with sets/reps/ROM target/frequency each, and `assignSession()` writes one `rehabilitation_plans` row + one `patient_exercise_plans` row per exercise (sharing that plan's `plan_id`), retiring whatever was previously active. The patient app's plan list reads exactly this |
| FR-6 | Exercise Plan Version Management | Medium | UC-16 | `version_no` field on `REHABILITATION_PLAN` only — **no class/method documented** | `backend/supabase/migrations/0003_*` | **Thin — see note 2.** `rehabilitation_plans` table now exists live but still has no `version_no` column — note 2's gap is confirmed, not closed |
| FR-7 | Wearable Device Connectivity | High | UC-4, UC-7 | BLE Client Manager, `pairAndCalibrate()` (Algorithm 6.1) | `Inteli_Rehab_Mobile_App/lib/features/home/wearable_connection_controller.dart`, `lib/features/home/bluetooth_rationale.dart`, `lib/features/onboarding/steps/wearable_setup_step.dart`, `firmware/src/ble/` | In Progress — `wearable_devices` table + RLS live (see note 5); app-side Communication Layer built (connect/reconnect/forget, in-context Bluetooth rationale per Rule 23) but pairing itself is simulated — no BLE plugin bridges to `firmware/src/ble/ble_server.*` yet |
| FR-8 | Sensor Data Acquisition | High | UC-7, UC-8 | `ExerciseSession` class, `start()` method | `Inteli_Rehab_Mobile_App/lib/features/exercises/session_simulator.dart` (`start()`/`_onTick()`), `firmware/src/sensors/` | In Progress — `sensor_readings` table + RLS live (see note 5); `SessionSimulator` generates a per-tick reading stream shaped like what BLE streaming would deliver, so the rest of the pipeline is buildable and testable now — real acquisition is blocked on FR-7's BLE plugin, no `sensor_readings` rows written yet |
| FR-9 | Sensor Calibration and Motion Processing | High | UC-5, UC-7 | `BiometricBaseline` class, `calibrate()`; `pairAndCalibrate()` (6.1), `computeJointAngle()` (6.2) | `Inteli_Rehab_Mobile_App/lib/features/onboarding/steps/calibration_step.dart`, `lib/features/exercises/processing/sensor_fusion.dart` | Implemented (simulated) — onboarding's calibration step captures a baseline (flexion/range) saved to `sessions`/`movement_analysis` (`posture_status='baseline_calibration'`); `SensorFusion.angleAtPhase()` is the joint-angle computation, standing in for `computeJointAngle()` until real IMU data exists |
| FR-10 | Rehabilitation Monitoring | High | UC-8, UC-10 | `SensorFusionEngine`, `EMGProcessor`; `trackRepetition()` (Algorithm 6.2) | `Inteli_Rehab_Mobile_App/lib/features/exercises/active_session_screen.dart`, `session_simulator.dart`, `processing/{sensor_fusion,emg_processor}.dart` | Implemented (simulated pipeline) — Active Session screen drives `SessionSimulator`, which calls `SensorFusion`/`EmgProcessor`/`AiEngine` every tick; rep counting, ROM, muscle activation and safety tier are all live and saved to `sessions`/`movement_analysis`/`alerts`. Blocked on FR-7/FR-8 for real sensor input |
| FR-11 | Progress Monitoring and Reporting | High | UC-11 | `ProgressRecord`, `Report` classes; `generateSessionReport()` (Algorithm 6.6) | `Inteli_Rehab_Mobile_App/lib/features/progress/` (patient-facing), `web_dashboard/src/features/physiotherapist/patient-list/` (physio-facing) | In Progress — patient side **Implemented**: ROM trend, recovery/sessions/adherence summary, achievements, and Session History/Detail (`generateSessionReport()`'s patient-facing analogue) all read live `sessions`/`movement_analysis`/`alerts`/`patient_badges`. Physio-facing side: `PatientsPage.jsx` now reads real sessions too (see FR-16); a dedicated `patient-list` report view is still not built |
| FR-12 | Digital Twin Visualization | High | UC-8, UC-10 | `DigitalTwinRenderer` class | `Inteli_Rehab_Mobile_App/lib/features/home/widgets/{digital_twin_card,static_joint_pose}.dart` (Home, static), `lib/features/exercises/widgets/live_digital_twin.dart` (Active Session, live) | Implemented — a 2D `CustomPainter` joint renderer (not literally 3D), deliberately split into a still snapshot on Home and a genuinely live, safety-tier-colour-coded twin during a session, per the corrected requirement that Home stay a snapshot and the session screen own the live view |
| FR-13 | AI Movement Assessment | High | UC-10, UC-15 | `AIInferenceEngine` (Autoencoder), `AlertManager`; `detectMovementAnomaly()` (Algorithm 6.4) | `Inteli_Rehab_Mobile_App/lib/features/exercises/processing/ai_engine.dart` (`assessRep()`), `Inteli_Rehab_AI_Pipeline/` | In Progress — `movement_analysis` table + RLS live (see note 5); `AiEngine.assessRep()` produces a per-rep safety-tier call and alert, written to `alerts` and reflected in `movement_analysis.posture_status`/`compensation_detected` — a stand-in with a documented swap-in seam (see its doc comment), not a trained autoencoder; nothing exported from `Inteli_Rehab_AI_Pipeline` yet |
| FR-14 | Corrective Feedback System | High | UC-10, UC-15 | `AlertManager`, `ALERT` entity | `Inteli_Rehab_Mobile_App/lib/features/exercises/widgets/safety_banner.dart`, `exercises_repository.dart` (`alerts` writes) | Implemented — three-tier real-time banner (shape *and* colour, largest element on screen while active) with inline acknowledge for the "unsafe" tier; every correction/unsafe rep is saved to `alerts` and shown factually ("N correction prompts") in the Session Summary and Progress's Session History/Detail. Physio-side alert-acknowledgment UI in the web portal still doesn't consume these rows (see FR-16) |
| FR-15 | Fatigue Monitoring | High | UC-10, UC-15 | `AIInferenceEngine` (LSTM); `detectFatigueTrend()` (Algorithm 6.5) | `Inteli_Rehab_Mobile_App/lib/features/exercises/processing/emg_processor.dart` (`fatigueIncrement()`/`levelOf()`), `lib/features/exercises/widgets/fatigue_meter.dart` | Implemented (simulated) — fatigue accumulates per rep and is shown via `FatigueMeter`; reaching "critical" auto-pauses the session with an offered (not forced) break, matching UC-10's alt-flow. `EmgProcessor`'s increment is a fixed-plus-random step, not an LSTM trend model — same swap-in seam as `AiEngine` |
| FR-16 | Physiotherapist Dashboard | High | UC-11, UC-15 | Physiotherapist Web Dashboard, `getPatientProgress()` | `Intelli_Rehab_Web_Portal/src/presentation/physio/` | In Progress — `ApprovalsPage.jsx` and `PatientsPage.jsx` (via `PatientUseCases`) now read/write real Supabase data (approve/decline persist; patient detail shows real onboarding answers, injuries, wearable and sessions); `DashboardPage.jsx`, `ExercisesPage.jsx` and `AtRiskPage.jsx` still read mock data (`infrastructure/physio/constants/mockData.js`) |
| FR-17 | Rehabilitation Plan Management | High | UC-13, UC-14, UC-16 | `ExerciseProtocol.adjust()`, `approveProgression()` | `Intelli_Rehab_Web_Portal/src/domain/physio/usecases/ExercisePlanUseCases.js` | In Progress — assigning/replacing a session is implemented (see FR-5); there's still no dedicated ROM-target-adjustment or plan-history UI (`rom-targets`/`modify-plan`) beyond re-running Assign, and no `approveProgression()`-style workflow — version_no's own gap (note 2) is unrelated and still open |
| FR-18 | Clinic Administration | Medium | UC-17, UC-18, UC-19 | `ClinicAdmin` class, `addPhysiotherapist()` | `web_dashboard/src/features/clinic-admin/manage-physios/`, `backend/supabase/migrations/0001_*` | In Progress — add/approve physiotherapist working end-to-end in `Intelli_Rehab_Web_Portal` as of 2026-09-23 (credentialing migration was previously unapplied — see note 5) |
| FR-19 | Cloud Synchronization and Notifications | High | UC-15, UC-19 | Offline-First Sync Queue, Cloud Backend API; `syncToCloud()`/`queueForSync()` (Algorithm 6.6) | `backend/supabase/functions/notify-physio/` (not built), `Inteli_Rehab_Mobile_App/lib/features/exercises/session_journal.dart` (`enqueue()`/`syncPending()`) | In Progress — `SessionJournal` **is** the offline-first sync queue: a finished session queues on disk if the upload fails and syncs automatically next time the app loads (`HomeScreen`/`HomeShell`), retries are idempotent (client-generated ids + `upsert(..., ignoreDuplicates: true)`) so a partial failure never duplicates rows. No `notify-physio` edge function exists — a physio isn't pushed a notification, only sees new data on their next portal load |

## Reconciliation Notes

1. **FR-3 gap:** The SRS cites "UC-4 (Manage Patient Profile)" as FR-3's source, but
   UC-4 in the finalized Use Case Description section is actually *Connect Wearable
   Device*. No documented use case covers profile/injury data entry. Before the next
   iteration, either (a) write a UC-20: Manage Patient Profile and route it through
   the normal use-case → FR pipeline, or (b) fold profile capture into UC-1
   (Register/Login) as an extended registration step and update FR-1's scope to
   say so explicitly. Don't leave this implicit — it'll surface as a missing
   screen when someone builds the patient onboarding flow.

2. **FR-6 thin coverage:** Only a `version_no` integer field exists in the data
   model (SDD §5.3, `REHABILITATION_PLAN`). There's no documented class, method,
   or UI for actually viewing plan history — just a column that increments.
   Decide now whether this is truly a UI feature (a "plan history" view for
   physiotherapists) or just an audit field nobody browses, and update the FR-6
   requirement text to match reality rather than implying a feature that isn't
   designed yet.

3. **Original SRS "Source" field corrections** (for anyone diffing against the
   SRS PDF directly): FR-1, FR-2, FR-7, and FR-11 in the SRS document cite UC
   numbers that don't match the finalized Use Case Description table (likely
   leftover from an earlier UC ordering). The UC Source column above reflects
   the corrected mapping against the final UC-1–UC-19 list. Recommend fixing
   the SRS PDF's Source fields directly next revision so this file and the SRS
   don't silently diverge again.

4. **SDD Table 7.1 is now superseded** by this file for FR-to-component mapping.
   Leave a pointer in the SDD (§7) back to this file rather than maintaining two
   traceability matrices in parallel — divergence is exactly how the original
   mismatch happened.

5. **2026-09-23 schema audit:** the live Supabase project has significantly more
   structure than anything committed to this repo — `alerts`, `movement_analysis`,
   `badges`, `patient_badges`, `rehabilitation_plans`, `sensor_readings`, and
   `wearable_devices` all exist live with RLS policies, built directly against
   the dashboard with no migration file ever committed. `Intelli_Rehab_Web_Portal/scripts/supabase_full_schema_snapshot.sql`
   now captures that state in source control. Separately, `physiotherapists`
   credentialing (`supabase_credentialing_and_approval.sql`) had never been run,
   which silently broke the admin's add/approve-physiotherapist flow — now fixed.
   None of the newly-discovered tables have any application code reading or
   writing them yet (confirmed by reviewing `Intelli_Rehab_Web_Portal/src`), so
   "In Progress" above means *schema only* unless a row says otherwise — don't
   read it as feature-complete. **Superseded for `alerts`, `movement_analysis`,
   `wearable_devices` and `patient_badges` by note 7** — the mobile app now
   reads and writes all four.

6. **FR-3 built despite the note 1 gap:** Personal Info, Care Team (read-only,
   with a plain "contact your clinic" rather than an unsupported edit button),
   Wearable and Account & Security were all built directly from documented
   `PATIENT`/`WEARABLE_DEVICE` fields — no setting invented past what the data
   dictionary already has. `update_patient_profile` (a SECURITY DEFINER RPC
   scoped to exactly the columns this screen edits) is the same pattern as
   `register_patient_self`/`choose_clinic_and_physio`: a blanket `UPDATE` RLS
   policy on `patients` would let a signed-in patient overwrite
   `approved`/`clinic_id`/`physio_id` on their own row, so those stay
   unreachable from the client on purpose. Note 1's actual gap — no UC number
   covers this screen — is still open and should still be closed in the next
   SRS revision; it just no longer blocks the code.

7. **2026-09-29 — Intelligence & Processing Layer split (SDD §3.1.3):**
   `SessionSimulator` used to do sensor fusion, EMG processing and movement-
   error inference inline, in one class. It's now three separate classes —
   `SensorFusion`, `EmgProcessor`, `AiEngine` (all under
   `Inteli_Rehab_Mobile_App/lib/features/exercises/processing/`) — each unit-
   tested on its own (`test/processing_layer_test.dart`) and each a documented
   swap-in point for real IMU fusion / EMG electrodes / a trained model once
   FR-7/FR-8 and `Inteli_Rehab_AI_Pipeline` exist. `SessionSimulator` is now
   just the orchestrator: it ticks the clock and calls the three in the same
   order every time, so seeded tests stay deterministic. This is also where
   `alerts`, `movement_analysis` and `wearable_devices` picked up real
   application code (see the caveat added to note 5) — a full session now
   writes `sessions` + `movement_analysis` + one `alerts` row per correction/
   unsafe rep, all idempotently (client-generated ids), and `wearable_devices`
   is read/written by `WearableConnectionController` and Profile's
   [Forget wearable]. `patient_badges` is read (Progress's Achievements) but
   nothing writes it yet — no code awards a badge.

## Maintenance

- Update **Status** as each FR moves through implementation:
  `Not Started → In Progress → Implemented → Tested → Verified`.
- When a UC or FR is added/changed in a future SRS revision, update this file in
  the same PR — don't let it lag behind like the SDD copy did.
- If a design component doesn't exist yet when you fill this in (e.g. no class
  diagram entry), write "TBD" rather than inventing one — an honest gap is more
  useful than a fabricated mapping.
