-- Session motion replay: the elbow angle and muscle activation the band streamed during an exercise
-- session, so the physiotherapist can replay it in the portal (chart + 3D arm).
--
-- One row per session (not one row per sample: a minute is ~1,000 samples). The mobile app writes it
-- right after the session row, with the same client-generated session id, so a retried upload is a
-- no-op. Recorded at ~15 Hz:
--   t_ms     time since the session started, milliseconds
--   angle    elbow angle, degrees (0 = the band's zero pose, arm straight)
--   emg      biceps activation, %MVC (0-100)
--   events   [{ "t_ms": 1234, "type": "rep" }, { "t_ms": 2000, "type": "tier", "tier": "unsafe", "message": "..." }]
--   side     'left' | 'right' - which arm model replays it
--
-- Run after supabase_core_tables.sql. Safe to run any time - idempotent, touches no existing data.

create table if not exists public.session_motion (
  session_id    uuid primary key references public.sessions(id) on delete cascade,
  created_at    timestamptz not null default now(),
  sample_rate_hz real,
  side          text not null default 'left',
  t_ms          integer[] not null,
  angle         real[] not null,
  emg           real[] not null,
  events        jsonb not null default '[]'::jsonb,
  constraint session_motion_side_check check (side in ('left', 'right')),
  constraint session_motion_lengths_check check (
    cardinality(t_ms) = cardinality(angle) and cardinality(t_ms) = cardinality(emg)
  ),
  -- About 40 minutes at 15 Hz; protects the table from a runaway upload.
  constraint session_motion_size_check check (cardinality(t_ms) <= 36000)
);

alter table public.session_motion enable row level security;

drop policy if exists "Clinic staff can view session motion" on public.session_motion;
create policy "Clinic staff can view session motion"
  on public.session_motion for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = session_motion.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own session motion" on public.session_motion;
create policy "Patients can view their own session motion"
  on public.session_motion for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = session_motion.session_id and public.is_own_patient(s.patient_id)
    )
  );

-- Patients only add motion to their own sessions; nobody can edit a recording afterwards.
drop policy if exists "Patients can record their own session motion" on public.session_motion;
create policy "Patients can record their own session motion"
  on public.session_motion for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = session_motion.session_id and public.is_own_patient(s.patient_id)
    )
  );

grant select, insert on public.session_motion to authenticated;
