// How long a patient rests between sets of an exercise. The physio sets it per exercise when assigning a
// session (patient_exercise_plans.rest_seconds); the app uses its own default when none is set.
export const DEFAULT_REST_SECONDS = 30;
export const MIN_REST_SECONDS = 10;
export const MAX_REST_SECONDS = 300;

// A whole number of seconds in range; anything else (blank, 0, text) becomes the default.
export function cleanRestSeconds(value) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_REST_SECONDS;
  return Math.min(MAX_REST_SECONDS, Math.max(MIN_REST_SECONDS, n));
}
