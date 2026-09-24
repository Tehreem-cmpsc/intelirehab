-- Brings rehabilitation_plans in line with the SDD data dictionary
-- (Table 5.8 REHABILITATION_PLAN) — status and version_no are documented
-- there but were never added to the live table.
--
-- No UI manages either field yet (see docs/traceability-matrix.md note 2 —
-- FR-6 is "thin": a column that increments, no actual plan-history view).
-- Adding the columns now just makes the schema match what's documented;
-- building the UI on top of them is a separate decision.
--
-- Safe to run any time — idempotent.

alter table public.rehabilitation_plans
  add column if not exists status     text not null default 'active',
  add column if not exists version_no integer not null default 1;
