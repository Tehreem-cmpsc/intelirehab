# INTELI-REHAB — Requirements Traceability Matrix

**Status:** Reconciled version. Supersedes SDD Table 7.1, which uses a different
(unreconciled) FR numbering scheme — see "Reconciliation Notes" at the bottom.

**Canonical source of FR numbering:** SRS, Functional Requirements section (FR-1–FR-19).
**Canonical source of UC numbering:** SRS, Use Case Description section (UC-1–UC-19).

This matrix is a living document. Update the **Status** column as work lands —
don't let it drift out of sync with the codebase the way the SDD's copy did.

| FR ID | Title | Priority | Correct UC Source(s) | Design Component (SDD) | Repo Location | Status |
|---|---|---|---|---|---|---|
| FR-1 | Patient Registration and Login | High | UC-1 | `Patient`/`User` class, `OnboardingController`, `AuthService.login()` | `mobile_app/lib/features/auth/`, `mobile_app/lib/features/onboarding/`, `backend/supabase/migrations/0001_*`, `0002_*` | Not Started |
| FR-2 | Role-Based Authentication | High | UC-1, UC-17, UC-19 | `AuthService`, role-based route guard | `mobile_app/lib/core/network/`, `web_dashboard/src/features/auth/`, `backend/supabase` (RLS policies) | In Progress — physio/admin login + RLS working in `Intelli_Rehab_Web_Portal`; no patient-facing auth |
| FR-3 | Patient Rehabilitation Profile Management | High | **⚠ GAP — no UC covers this** | `PATIENT`, `INJURY` entities only (ER diagram); no class/method or UI flow documented | *(needs a home — recommend a new feature folder once a UC exists)* | **Blocked — see note 1** (schema exists — see note 5) |
| FR-4 | Rehabilitation Exercise Database | High | UC-12 | `Exercise` class, `ExerciseRepository` | `web_dashboard/src/features/physiotherapist/exercise-database/`, `backend/supabase/migrations/0003_*` | In Progress — Supabase schema only (see note 5); UI still reads mock data |
| FR-5 | Personalized Exercise Plan Management | High | UC-13, UC-14, UC-16 | `ExerciseProtocol` class, `assign()` method | `web_dashboard/src/features/physiotherapist/assign-sessions/`, `mobile_app/lib/features/exercise_plan/`, `backend/supabase/migrations/0003_*` | In Progress — Supabase schema only (see note 5); UI still reads mock data |
| FR-6 | Exercise Plan Version Management | Medium | UC-16 | `version_no` field on `REHABILITATION_PLAN` only — **no class/method documented** | `backend/supabase/migrations/0003_*` | **Thin — see note 2.** `rehabilitation_plans` table now exists live but still has no `version_no` column — note 2's gap is confirmed, not closed |
| FR-7 | Wearable Device Connectivity | High | UC-4, UC-7 | BLE Client Manager, `pairAndCalibrate()` (Algorithm 6.1) | `mobile_app/lib/features/wearable_connect/`, `firmware/src/ble/` | In Progress — `wearable_devices` table + RLS live (see note 5); no BLE client code, mobile app not started |
| FR-8 | Sensor Data Acquisition | High | UC-7, UC-8 | `ExerciseSession` class, `start()` method | `mobile_app/lib/intelligence/sensor_fusion/`, `firmware/src/sensors/` | In Progress — `sensor_readings` table + RLS live (see note 5); no acquisition code yet |
| FR-9 | Sensor Calibration and Motion Processing | High | UC-5, UC-7 | `BiometricBaseline` class, `calibrate()`; `pairAndCalibrate()` (6.1), `computeJointAngle()` (6.2) | `mobile_app/lib/features/calibration/`, `mobile_app/lib/intelligence/sensor_fusion/` | Not Started |
| FR-10 | Rehabilitation Monitoring | High | UC-8, UC-10 | `SensorFusionEngine`, `EMGProcessor`; `trackRepetition()` (Algorithm 6.2) | `mobile_app/lib/features/rehab_session/`, `mobile_app/lib/intelligence/{sensor_fusion,emg_processor}/` | Not Started |
| FR-11 | Progress Monitoring and Reporting | High | UC-11 | `ProgressRecord`, `Report` classes; `generateSessionReport()` (Algorithm 6.6) | `mobile_app/lib/features/progress/`, `web_dashboard/src/features/physiotherapist/patient-list/` | In Progress — `sessions`/`emg_readings` schema live (see note 5); no report generation code |
| FR-12 | Digital Twin Visualization | High | UC-8, UC-10 | `DigitalTwinRenderer` class | `mobile_app/lib/intelligence/digital_twin_engine/`, `mobile_app/lib/features/digital_twin/` | Not Started |
| FR-13 | AI Movement Assessment | High | UC-10, UC-15 | `AIInferenceEngine` (Autoencoder), `AlertManager`; `detectMovementAnomaly()` (Algorithm 6.4) | `mobile_app/lib/intelligence/ai_inference/`, `ai_pipeline/src/models/` | In Progress — `movement_analysis` table + RLS live (see note 5); no inference model wired to it |
| FR-14 | Corrective Feedback System | High | UC-10, UC-15 | `AlertManager`, `ALERT` entity | `mobile_app/lib/features/feedback/` | In Progress — `alerts` table + RLS + acknowledgment workflow live (see note 5); no client UI consumes it |
| FR-15 | Fatigue Monitoring | High | UC-10, UC-15 | `AIInferenceEngine` (LSTM); `detectFatigueTrend()` (Algorithm 6.5) | `mobile_app/lib/intelligence/ai_inference/`, `ai_pipeline/src/models/` | Not Started |
| FR-16 | Physiotherapist Dashboard | High | UC-11, UC-15 | Physiotherapist Web Dashboard, `getPatientProgress()` | `web_dashboard/src/features/physiotherapist/` | In Progress — pages exist in `Intelli_Rehab_Web_Portal/src/presentation/physio/`; still wired to mock data, not Supabase |
| FR-17 | Rehabilitation Plan Management | High | UC-13, UC-14, UC-16 | `ExerciseProtocol.adjust()`, `approveProgression()` | `web_dashboard/src/features/physiotherapist/{assign-sessions,rom-targets,modify-plan}/` | In Progress — `rehabilitation_plans` + `patient_exercise_plans` schema live (see note 5); no UI wired to either |
| FR-18 | Clinic Administration | Medium | UC-17, UC-18, UC-19 | `ClinicAdmin` class, `addPhysiotherapist()` | `web_dashboard/src/features/clinic-admin/manage-physios/`, `backend/supabase/migrations/0001_*` | In Progress — add/approve physiotherapist working end-to-end in `Intelli_Rehab_Web_Portal` as of 2026-09-23 (credentialing migration was previously unapplied — see note 5) |
| FR-19 | Cloud Synchronization and Notifications | High | UC-15, UC-19 | Offline-First Sync Queue, Cloud Backend API; `syncToCloud()`/`queueForSync()` (Algorithm 6.6) | `backend/supabase/functions/notify-physio/`, `mobile_app/lib/data_sync/` | Not Started |

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
   the dashboard with no migration file ever committed. `Intelli_Rehab_Web_Portal/supabase_full_schema_snapshot.sql`
   now captures that state in source control. Separately, `physiotherapists`
   credentialing (`supabase_credentialing_and_approval.sql`) had never been run,
   which silently broke the admin's add/approve-physiotherapist flow — now fixed.
   None of the newly-discovered tables have any application code reading or
   writing them yet (confirmed by reviewing `Intelli_Rehab_Web_Portal/src`), so
   "In Progress" above means *schema only* unless a row says otherwise — don't
   read it as feature-complete.

## Maintenance

- Update **Status** as each FR moves through implementation:
  `Not Started → In Progress → Implemented → Tested → Verified`.
- When a UC or FR is added/changed in a future SRS revision, update this file in
  the same PR — don't let it lag behind like the SDD copy did.
- If a design component doesn't exist yet when you fill this in (e.g. no class
  diagram entry), write "TBD" rather than inventing one — an honest gap is more
  useful than a fabricated mapping.
