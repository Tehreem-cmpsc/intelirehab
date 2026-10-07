// Pure helpers for turning raw `sessions` rows into what the physio UI
// displays — shared between PatientUseCases (per-patient) and DashboardPage
// (clinic-wide, across every patient's sessions) so the two never compute
// "a week" or "a streak" differently.

export function formatSessionForUi(row) {
  const performedAt = new Date(row.performed_at);
  return {
    id: row.id, // for loading this session's movement replay
    date: performedAt.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    rom: row.rom ?? 0,
    quality: row.quality ?? 0,
    fatigue: row.fatigue ?? 0,
    reps: row.reps ?? 0,
    exercise: row.exercises?.name ?? "—",
    painLevel: row.pain_level ?? null, // the patient's own 0-10 rating, when they gave one
    endedReason: row.ended_reason ?? null, // why a session stopped early: pain, tired, band_problem, other
    performedAt,
  };
}

// Monday-anchored week bucket — simpler than ISO week numbers and good
// enough for "which week is this session in" grouping.
export function startOfWeek(date) {
  const d = new Date(date);
  const day = d.getDay(); // 0 = Sunday .. 6 = Saturday
  const diff = (day === 0 ? -6 : 1) - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

// Consecutive days (ending today, or yesterday if nothing's logged yet
// today) with at least one session.
export function computeStreak(sessionsDesc) {
  if (sessionsDesc.length === 0) return 0;

  const days = new Set(
    sessionsDesc.map((s) => {
      const d = new Date(s.performedAt);
      d.setHours(0, 0, 0, 0);
      return d.getTime();
    })
  );

  const cursor = new Date();
  cursor.setHours(0, 0, 0, 0);
  if (!days.has(cursor.getTime())) {
    cursor.setDate(cursor.getDate() - 1);
  }

  let streak = 0;
  while (days.has(cursor.getTime())) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

// Average ROM per week, oldest to newest, last `weekCount` weeks that
// actually have a session — not the last N calendar weeks, since most
// weeks won't have any data yet.
export function computeWeeklyRom(sessionsAsc, weekCount = 6) {
  const weekMap = new Map();
  for (const s of sessionsAsc) {
    const key = startOfWeek(s.performedAt).getTime();
    if (!weekMap.has(key)) weekMap.set(key, []);
    weekMap.get(key).push(s.rom ?? 0);
  }

  const weeks = [...weekMap.entries()].sort((a, b) => a[0] - b[0]).slice(-weekCount);
  return weeks.map(([, roms], i) => ({
    w: `W${i + 1}`,
    v: Math.round(roms.reduce((a, b) => a + b, 0) / roms.length),
  }));
}

// Session count per weekday for the current Mon–Sun week — matches the
// DashboardPage "Session activity" chart's Mon..Sun x-axis.
export function computeWeekdayActivity(sessionsAsc) {
  const weekStart = startOfWeek(new Date());
  const labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const counts = labels.map((day) => ({ day, s: 0 }));

  for (const s of sessionsAsc) {
    const diffDays = Math.floor((s.performedAt - weekStart) / (1000 * 60 * 60 * 24));
    if (diffDays >= 0 && diffDays < 7) counts[diffDays].s += 1;
  }
  return counts;
}

// YYYY-MM-DD in the user's own timezone. (toISOString() is UTC, which is the
// wrong calendar day for part of every day in e.g. Pakistan.)
export function localDateString(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}
