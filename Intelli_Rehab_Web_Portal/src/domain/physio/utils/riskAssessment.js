// Works out whether a patient needs attention, from their own exercise sessions.
//
// Nothing in the apps ever wrote patients.status = 'at-risk', so the At Risk page
// and the dashboard count were always empty. This derives it from the data the
// mobile app does save: each session's ROM and fatigue, and its movement_analysis
// posture_status ('unsafe' when the safety monitor stopped the patient).
//
// The thresholds are starting points, not clinical rules - have a physiotherapist
// review them. Each one is a named constant so it can be changed in one place.

export const UNSAFE_WINDOW_DAYS = 7; // an unsafe movement this recently flags the patient
export const ROM_DROP_SESSIONS = 3; // compare this many latest sessions...
export const ROM_DROP_POINTS = 15; // ...a fall of at least this many ROM points flags them
export const CRITICAL_FATIGUE = 3; // sessions.fatigue: 0 normal .. 3 critical
export const CRITICAL_FATIGUE_SESSIONS = 2; // this many latest sessions in a row at critical fatigue

const DAY_MS = 86400000;

const isUnsafe = (session) =>
  (session.movement_analysis ?? []).some((m) => m.posture_status === "unsafe");

// `sessionsDesc`: raw exercise-session rows (not the onboarding baseline), newest first.
// Returns a list of plain-language reasons; empty means nothing to flag.
export function assessRisk(sessionsDesc, now = new Date()) {
  const reasons = [];
  if (!sessionsDesc?.length) return reasons;

  const since = now.getTime() - UNSAFE_WINDOW_DAYS * DAY_MS;
  if (sessionsDesc.some((s) => isUnsafe(s) && new Date(s.performed_at).getTime() >= since)) {
    reasons.push(`Unsafe movement in the last ${UNSAFE_WINDOW_DAYS} days`);
  }

  const latest = sessionsDesc.slice(0, ROM_DROP_SESSIONS);
  if (latest.length === ROM_DROP_SESSIONS && latest.every((s) => s.rom != null)) {
    const oldestToNewest = [...latest].reverse().map((s) => s.rom);
    const falling = oldestToNewest.every((rom, i) => i === 0 || rom < oldestToNewest[i - 1]);
    const drop = oldestToNewest[0] - oldestToNewest[oldestToNewest.length - 1];
    if (falling && drop >= ROM_DROP_POINTS) {
      reasons.push(`ROM fell ${drop} points over the last ${ROM_DROP_SESSIONS} sessions`);
    }
  }

  const recent = sessionsDesc.slice(0, CRITICAL_FATIGUE_SESSIONS);
  if (recent.length === CRITICAL_FATIGUE_SESSIONS && recent.every((s) => (s.fatigue ?? 0) >= CRITICAL_FATIGUE)) {
    reasons.push(`Critical fatigue in the last ${CRITICAL_FATIGUE_SESSIONS} sessions`);
  }

  return reasons;
}
