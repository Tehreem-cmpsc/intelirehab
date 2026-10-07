import { DEFAULT_REST_SECONDS, cleanRestSeconds } from "./restSeconds";

// A template is the list the assign form sends when it saves a plan: one entry per exercise. These helpers
// turn it into form rows and back, and keep whatever a template holds inside what the form allows.

export const FREQUENCIES = ["Daily", "Every other day", "3× per week", "Weekly"];
export const MAX_TEMPLATE_NAME = 60;

// Limits of each field in the assign form.
const LIMITS = { sets: [1, 6, 3], reps: [3, 20, 10], romTarget: [20, 100, 70] };

const clampInt = (value, [min, max, fallback]) => {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
};

// The name as it will be saved: spaces tidied, not empty, not too long. null when there is nothing to save.
export function cleanTemplateName(name) {
  const tidy = String(name ?? "").replace(/\s+/g, " ").trim().slice(0, MAX_TEMPLATE_NAME).trim();
  return tidy || null;
}

// The form rows, as the list to store: only rows with an exercise chosen.
export function exercisesFromRows(rows) {
  return (rows ?? [])
    .filter((r) => r.exerciseId)
    .map((r) => ({
      exerciseId: r.exerciseId,
      sets: clampInt(r.sets, LIMITS.sets),
      reps: clampInt(r.reps, LIMITS.reps),
      romTarget: clampInt(r.romTarget, LIMITS.romTarget),
      frequency: FREQUENCIES.includes(r.frequency) ? r.frequency : FREQUENCIES[0],
      restSeconds: cleanRestSeconds(r.restSeconds),
    }));
}

// A stored template as form rows. Exercises no longer in the catalogue are left out (counted in `dropped`),
// repeats of the same exercise are kept once, and every value is brought inside the form's limits.
export function rowsFromTemplate(template, catalogue, makeKey = () => Math.random().toString(36).slice(2)) {
  const known = new Set((catalogue ?? []).map((e) => e.id));
  const seen = new Set();
  const rows = [];
  let dropped = 0;
  for (const e of Array.isArray(template?.exercises) ? template.exercises : []) {
    if (!e || !known.has(e.exerciseId) || seen.has(e.exerciseId)) {
      dropped += 1;
      continue;
    }
    seen.add(e.exerciseId);
    rows.push({
      key: makeKey(),
      exerciseId: e.exerciseId,
      sets: clampInt(e.sets, LIMITS.sets),
      reps: clampInt(e.reps, LIMITS.reps),
      romTarget: clampInt(e.romTarget, LIMITS.romTarget),
      frequency: FREQUENCIES.includes(e.frequency) ? e.frequency : FREQUENCIES[0],
      restSeconds: e.restSeconds == null ? DEFAULT_REST_SECONDS : cleanRestSeconds(e.restSeconds),
    });
  }
  return { rows, dropped };
}
