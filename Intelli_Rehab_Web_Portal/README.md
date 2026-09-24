# Inteli Rehab — Web Portal

Clinic Admin and Physiotherapist dashboard for Inteli Rehab (a smart wearable
rehabilitation system). React + Vite frontend backed by Supabase (Postgres +
Auth). Per the SDD's layered architecture (§3.1.7), this repo is only the
**Presentation / Monitoring Layer** — the patient-facing app, sensor
processing, and AI inference live in the separate `Inteli_Rehab_Mobile_App`
and `Inteli_Rehab_AI_Pipeline` projects.

## Setup

1. **Install dependencies:**
   ```
   npm install
   ```

2. **Create a Supabase project** at [supabase.com](https://supabase.com) (or
   use an existing one).

3. **Copy `.env.example` to `.env`** and fill in your project's URL and
   publishable key (Supabase Dashboard → Settings → API):
   ```
   cp .env.example .env
   ```

4. **Run the SQL migrations**, in this exact order, in the Supabase
   Dashboard's SQL Editor. Each one is idempotent (safe to re-run), but
   later files depend on tables/functions earlier ones create:

   1. `supabase_setup.sql` — `clinics`, `physiotherapists`
   2. `supabase_fix_rls_recursion.sql` — cross-table RLS helper functions
   3. `supabase_credentialing_and_approval.sql` — physio credentialing fields + approval policy
   4. `supabase_core_tables.sql` — `patients`, `exercises`, `patient_exercise_plans`, `sessions`, `emg_readings`, `activity_log`
   5. `supabase_full_schema_snapshot.sql` — `rehabilitation_plans`, `wearable_devices`, `sensor_readings`, `movement_analysis`, `alerts`, `badges`, `patient_badges`
   6. `supabase_rehabilitation_plan_fields.sql` — adds `status`/`version_no` to `rehabilitation_plans`
   7. `supabase_rls_hardening.sql` — policy/default fixes found during a security review
   8. `supabase_first_login_password_reset.sql` — forces a physio to set their own password on first login
   9. `supabase_patient_self_registration.sql` — lets a patient claim a clinic-created record
   10. `supabase_seed_exercises.sql` — seeds the exercise library

5. **Disable "Confirm email"** — Supabase Dashboard → Authentication →
   Providers → Email → turn off "Confirm email". Admins create physio
   accounts directly (see below), not through a self-serve signup + email
   confirmation flow.

6. **Run it:**
   ```
   npm run dev       # local dev server
   npm run build      # production build → dist/
   npm run preview    # serve the production build locally
   npm run lint        # oxlint
   ```

## How accounts work

There's no public sign-up. A clinic administrator's `clinics` row and a
physiotherapist's `physiotherapists` row both have to exist before anyone
can log in as that role — there's currently no UI to create the first
clinic admin account, so that first row needs to be inserted directly in
the Supabase Table Editor (with a matching `auth.users` entry — create the
user under Authentication → Users first, then insert the `clinics` row with
the same email).

Once a clinic admin exists, they can add physiotherapists from the portal.
Physios are given an initial password directly by the admin (no email
delivery — see "Email delivery" below) and are forced to set their own
password on first login.

## Email delivery

Supabase's built-in email sender is rate-limited and not meant for real
delivery. This app is built to need **no outbound email at all** for
account creation: admins set a physio's initial password directly rather
than emailing a reset link. If you want real transactional email later
(e.g. for Supabase's password-reset "Forgot password" flow, which the login
page still offers), configure a custom SMTP provider under Authentication →
Settings → SMTP Settings.

## Known gaps

- No UI exists yet to add a patient directly (only physiotherapists can be
  added from this portal) — patients are meant to self-register from the
  mobile app using a registration ID a physio gives them.
- No session-logging UI anywhere yet, so ROM/EMG charts will show "no
  session data yet" until the mobile app (or a manual `sessions` insert)
  produces real data.
- `docs/traceability-matrix.md` tracks which SRS requirements are actually
  implemented vs. schema-only vs. not started.
