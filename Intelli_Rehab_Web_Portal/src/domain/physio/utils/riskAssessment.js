// Works out whether a patient needs attention, from their own exercise sessions.
//
// Nothing in the apps ever wrote patients.status = 'at-risk', so the At Risk page
// and the dashboard count were always empty. This derives it from the data the
// mobile app does save: each session's ROM, fatigue and pain rating, and its
// movement_analysis posture_status ('unsafe' when the safety monitor stopped the
// patient), plus how long it has been since they last exercised.
//
// The thresholds are starting points, not clinical rules. A clinic administrator can change them
// (clinics.risk_settings, edited on the Clinic profile page); DEFAULT_RISK_SETTINGS is what applies
// until they do. Reasons carry a severity so the At Risk list can put the worst first.

export const DEFAULT_RISK_SETTINGS = {
  unsafeWindowDays: 7, // an unsafe movement or a high pain rating this recently flags the patient
  romDropSessions: 3, // compare this many latest sessions...
  romDropPoints: 15, // ...a fall of at least this many ROM points flags them
  criticalFatigueSessions: 2, // this many latest sessions in a row at critical fatigue
  highPain: 7, // a patient's own 0-10 pain rating at or above this flags them
  inactiveDays: 7, // no session (or warning) for this many days flags them
};

// The same values under their older names, for anything that still imports them.
export const UNSAFE_WINDOW_DAYS = DEFAULT_RISK_SETTINGS.unsafeWindowDays;
export const ROM_DROP_SESSIONS = DEFAULT_RISK_SETTINGS.romDropSessions;
export const ROM_DROP_POINTS = DEFAULT_RISK_SETTINGS.romDropPoints;
export const CRITICAL_FATIGUE = 3; // sessions.fatigue: 0 normal .. 3 critical
export const CRITICAL_FATIGUE_SESSIONS = DEFAULT_RISK_SETTINGS.criticalFatigueSessions;
export const HIGH_PAIN = DEFAULT_RISK_SETTINGS.highPain;

// What the admin can change, with the range each accepts (also used to clean up stored values).
export const RISK_SETTING_FIELDS = [
  { key: "unsafeWindowDays", label: "Unsafe movement or high pain counts for (days)", min: 1, max: 90 },
  { key: "highPain", label: "High pain rating (out of 10)", min: 1, max: 10 },
  { key: "romDropSessions", label: "Sessions compared for a falling ROM", min: 2, max: 10 },
  { key: "romDropPoints", label: "ROM fall that flags a patient (points)", min: 1, max: 100 },
  { key: "criticalFatigueSessions", label: "Critical-fatigue sessions in a row", min: 1, max: 10 },
  { key: "inactiveDays", label: "Days without a session", min: 1, max: 90 },
];

// Stored settings may be missing, partial, or hand-edited: anything that is not a whole number in range
// falls back to the default for that one setting.
export function normalizeRiskSettings(raw) {
  const out = { ...DEFAULT_RISK_SETTINGS };
  if (!raw || typeof raw !== "object") return out;
  for (const { key, min, max } of RISK_SETTING_FIELDS) {
    const v = Number(raw[key]);
    if (Number.isInteger(v) && v >= min && v <= max) out[key] = v;
  }
  return out;
}

export const SEVERITY = { INACTIVE: 1, FALLING: 2, FATIGUE: 2, UNSAFE: 3, PAIN: 3 };

const DAY_MS = 86400000;

const isUnsafe = (session) =>
  (session.movement_analysis ?? []).some((m) => m.posture_status === "unsafe");

// `allSessionsDesc`: raw exercise-session rows (not the onboarding baseline), newest first.
// `reviewedAt`: when a physiotherapist last sent the patient a warning (patients.risk_reviewed_at).
// Sessions up to then have been dealt with, so only later ones count: a warned patient leaves the At
// Risk list, and returns only if sessions done after the warning show a problem - or if they simply
// stop exercising.
// Returns [{ text, severity }]; empty means nothing to flag.
export function assessRiskDetailed(allSessionsDesc, now = new Date(), reviewedAt = null, settings = null) {
  const s = normalizeRiskSettings(settings);
  const reasons = [];
  if (!allSessionsDesc?.length) return reasons;

  const reviewedMs = reviewedAt ? new Date(reviewedAt).getTime() : null;
  const reviewed = reviewedMs != null && !Number.isNaN(reviewedMs);
  const sessionsDesc = reviewed
    ? allSessionsDesc.filter((x) => new Date(x.performed_at).getTime() > reviewedMs)
    : allSessionsDesc;

  const since = now.getTime() - s.unsafeWindowDays * DAY_MS;
  if (sessionsDesc.some((x) => isUnsafe(x) && new Date(x.performed_at).getTime() >= since)) {
    reasons.push({ text: `Unsafe movement in the last ${s.unsafeWindowDays} days`, severity: SEVERITY.UNSAFE });
  }

  const painful = sessionsDesc.find(
    (x) => (x.pain_level ?? 0) >= s.highPain && new Date(x.performed_at).getTime() >= since
  );
  if (painful) {
    reasons.push({
      text: `Pain rated ${painful.pain_level}/10 in the last ${s.unsafeWindowDays} days`,
      severity: SEVERITY.PAIN,
    });
  }

  const latest = sessionsDesc.slice(0, s.romDropSessions);
  if (latest.length === s.romDropSessions && latest.every((x) => x.rom != null)) {
    const oldestToNewest = [...latest].reverse().map((x) => x.rom);
    const falling = oldestToNewest.every((rom, i) => i === 0 || rom < oldestToNewest[i - 1]);
    const drop = oldestToNewest[0] - oldestToNewest[oldestToNewest.length - 1];
    if (falling && drop >= s.romDropPoints) {
      reasons.push({
        text: `ROM fell ${drop} points over the last ${s.romDropSessions} sessions`,
        severity: SEVERITY.FALLING,
      });
    }
  }

  const recent = sessionsDesc.slice(0, s.criticalFatigueSessions);
  if (recent.length === s.criticalFatigueSessions && recent.every((x) => (x.fatigue ?? 0) >= CRITICAL_FATIGUE)) {
    reasons.push({
      text: `Critical fatigue in the last ${s.criticalFatigueSessions} sessions`,
      severity: SEVERITY.FATIGUE,
    });
  }

  // Gone quiet: nothing since their last session, or since the warning if that came later. Only for a
  // patient who has exercised before - a new patient with no sessions yet is not "inactive".
  const lastSessionMs = new Date(allSessionsDesc[0].performed_at).getTime();
  const anchor = reviewed ? Math.max(lastSessionMs, reviewedMs) : lastSessionMs;
  const quietDays = Math.floor((now.getTime() - anchor) / DAY_MS);
  if (!Number.isNaN(anchor) && quietDays >= s.inactiveDays) {
    reasons.push({
      text: `No session for ${quietDays} days${reviewed && reviewedMs >= lastSessionMs ? " since the warning" : ""}`,
      severity: SEVERITY.INACTIVE,
    });
  }

  return reasons;
}

// The same, as plain-language reasons only.
export function assessRisk(allSessionsDesc, now = new Date(), reviewedAt = null, settings = null) {
  return assessRiskDetailed(allSessionsDesc, now, reviewedAt, settings).map((r) => r.text);
}

export const riskSeverity = (detailed) => detailed.reduce((worst, r) => Math.max(worst, r.severity), 0);
