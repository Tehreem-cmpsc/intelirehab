-- The Home dashboard's Digital Twin card shows joint angle (already in
-- movement_analysis.joint_angle) alongside muscle activation, but there was
-- nowhere to save the latter — the mobile app's EmgProcessor computes an
-- activation level per rep (Blue/Green/Orange/Red), but movement_analysis
-- had no column for a session-level summary of it.
--
-- Safe to run any time — idempotent.

alter table public.movement_analysis
  add column if not exists muscle_activation text;

alter table public.movement_analysis drop constraint if exists movement_analysis_muscle_activation_check;
alter table public.movement_analysis add constraint movement_analysis_muscle_activation_check
  check (muscle_activation is null or muscle_activation in ('resting', 'light', 'moderate', 'high'));
