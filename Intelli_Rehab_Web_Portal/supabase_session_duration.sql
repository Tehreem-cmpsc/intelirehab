-- The mobile app's Active Session screen tracks how long a session ran
-- (SessionSimulator's stopwatch), but `sessions` had nowhere to save it —
-- Session History (Progress screen, patient-facing UC-11 extension) needs
-- a real duration per row, not a fabricated one.
--
-- Safe to run any time — idempotent.

alter table public.sessions
  add column if not exists duration_seconds integer;

alter table public.sessions drop constraint if exists sessions_duration_seconds_check;
alter table public.sessions add constraint sessions_duration_seconds_check
  check (duration_seconds is null or duration_seconds >= 0);
