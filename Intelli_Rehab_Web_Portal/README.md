# Inteli Rehab — Web Portal

Clinic Admin and Physiotherapist dashboard for Inteli Rehab (a smart wearable
rehabilitation system). React + Vite frontend backed by Supabase (Postgres +
Auth + Edge Functions). Per the SDD's layered architecture (§3.1.7), this repo
is only the **Presentation / Monitoring Layer** — the patient-facing app,
sensor processing, and AI inference live in the separate
`Inteli_Rehab_Mobile_App` and `Inteli_Rehab_AI_Pipeline` projects.

## Local development

```
npm install
cp .env.example .env     # fill in VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_KEY
npm run dev              # dev server
npm run lint             # oxlint
npm test                 # vitest
npm run build            # production build -> dist/
```

The app refuses to start without both environment variables and says so.

## Deploying (checklist)

### 1. Database

In the Supabase SQL editor, on a **fresh** project, run in this order. Each
script is idempotent, but later ones depend on earlier ones:

1. `supabase_setup.sql` — `clinics`, `physiotherapists` (refuses to run if they hold data)
2. `supabase_fix_rls_recursion.sql` — cross-table RLS helper functions
3. `supabase_credentialing_and_approval.sql` — physio credentialing fields + approval policy
4. `supabase_core_tables.sql` — `patients`, `exercises`, `patient_exercise_plans`, `sessions`, `emg_readings`, `activity_log`
5. `supabase_full_schema_snapshot.sql` — `rehabilitation_plans`, `wearable_devices`, `sensor_readings`, `movement_analysis`, `alerts`, `badges`, `patient_badges`
6. `supabase_rehabilitation_plan_fields.sql`, `supabase_session_duration.sql`, `supabase_movement_analysis_activation.sql`
7. `supabase_rls_hardening.sql`
8. `supabase_first_login_password_reset.sql`
9. `supabase_patient_self_registration.sql`, `supabase_patient_onboarding.sql`, `supabase_patient_onboarding_v2.sql`
10. `supabase_patient_choose_clinic_physio.sql`, `supabase_patient_profile_self_edit.sql`, `supabase_patient_wearable_sync.sql`, `supabase_patient_delete_account.sql`
11. `supabase_assign_session_rpc.sql` — assigns an exercise session in one transaction; `supabase_wearable_presence.sql` — live wearable connectivity (also enable Realtime, see below)
12. `supabase_seed_exercises.sql` — the exercise library (generated from `data/exercises.csv`)
13. `supabase_security_hardening.sql` — **last**

Steps 6 onward were ordered from each script's dependencies and have not been
run end to end: rehearse on a scratch Supabase project first.

Afterwards, check that no clinic is without an admin:

```sql
select id, name, email from clinics where admin_user_id is null;
```

### 2. Supabase Auth settings

Dashboard → Authentication:

- turn **Confirm email ON** (this is what stops anyone signing up with a
  clinic's email address),
- set the **Site URL** and add the portal URL to the **redirect allow-list**,
- configure **custom SMTP** (the built-in sender is rate-limited; password
  reset emails depend on it).

### 3. Edge Functions

```
supabase functions deploy manage-physiotherapist
supabase functions deploy physio-auth --no-verify-jwt
supabase secrets set PORTAL_URL=https://<portal> PORTAL_ORIGIN=https://<portal>
```

- `manage-physiotherapist` — creates / removes physios server-side (clinic admins only).
- `physio-auth` — physiotherapist-ID sign-in and password reset, with a
  per-ID attempt limit. Callers aren't signed in yet, hence `--no-verify-jwt`.

### 4. Hosting

- Static build: `npm run build` -> `dist/`. Set `VITE_SUPABASE_URL` and
  `VITE_SUPABASE_PUBLISHABLE_KEY` in the host's **build** environment.
- Routing uses URL hashes (`#/app/patients/<id>`), so no SPA rewrite rule is needed.
- Security headers (CSP, HSTS, frame/sniff protection) ship in
  `public/_headers` (Netlify / Cloudflare Pages) and `vercel.json` (Vercel).
  Delete the one you don't use. If Supabase uses a custom domain, add it to
  `connect-src`.

### Live wearable status

The physio portal shows whether a patient's band is connected **right now**
(green, with a pulse), paired but not connected (amber, with "last seen"), or
not paired. It needs `supabase_wearable_presence.sql` **and** the updated
mobile app, which reports presence every 15 s while its Bluetooth link is up.
A band counts as live only if it reported connected within the last 45 s, so a
phone that dies or goes out of range expires on its own. Until the mobile app
is updated, every paired patient will correctly read "Paired · not connected".

## How accounts work

There is no public sign-up for staff.

- **First clinic admin** (one-time, manual): create the user under Supabase
  Authentication → Users (tick "Auto Confirm"), then insert the clinic row
  with that user's id as the admin:
  ```sql
  insert into clinics (name, email, admin_user_id)
  values ('Clinic name', 'admin@clinic.com', '<auth user uuid>');
  ```
  Admin access follows `clinics.admin_user_id`, not the email address.
- **Physiotherapists** are added by the admin from the portal. The portal
  generates a temporary password, shown **once**. The physio starts as
  *Pending*, must be approved by the admin, and must choose their own password
  at first login. They sign in with their Physiotherapist ID.
- **Patients** register in the mobile app and are approved by a physio from
  the Approvals page.

## Known gaps

- No UI to add a patient directly from the portal.
- Charts show "no session data yet" until the mobile app produces sessions.
- Sessions are loaded for the last 90 days (plus each patient's baseline), so
  patients inactive for longer show "No sessions in the last 90 days".
- Temporary physio passwords are handed over by the admin; move to an email
  invite once SMTP is configured.
- `docs/traceability-matrix.md` tracks which SRS requirements are implemented.
