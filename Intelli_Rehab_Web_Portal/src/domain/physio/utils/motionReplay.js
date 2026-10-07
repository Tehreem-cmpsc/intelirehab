// Pure helpers for replaying a session's recorded movement (SessionUseCases.getMotion):
// what the arm looked like at any moment, so the chart cursor and the 3D arm always agree.

// Index of the last sample at or before time t (seconds), by binary search; -1 before the first.
export function sampleIndexAt(times, t) {
  let lo = 0;
  let hi = times.length - 1;
  if (hi < 0 || t < times[0]) return -1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (times[mid] <= t) lo = mid;
    else hi = mid - 1;
  }
  return lo;
}

// Elbow angle and muscle activation at time t, interpolated between the two nearest samples.
export function poseAt(motion, t) {
  const { t: times, angle, emg } = motion;
  if (!times.length) return { angle: 0, emg: 0 };
  const i = sampleIndexAt(times, t);
  if (i < 0) return { angle: angle[0], emg: emg[0] };
  if (i >= times.length - 1) return { angle: angle[i], emg: emg[i] };
  const span = times[i + 1] - times[i];
  const f = span > 0 ? Math.min(1, Math.max(0, (t - times[i]) / span)) : 0;
  return {
    angle: angle[i] + (angle[i + 1] - angle[i]) * f,
    emg: emg[i] + (emg[i + 1] - emg[i]) * f,
  };
}

// The safety state (normal / needsCorrection / unsafe) in force at time t, and its message if any.
export function tierAt(events, t) {
  let tier = "normal";
  let message = null;
  for (const e of events) {
    if (e.type !== "tier" || e.t > t) continue;
    tier = e.tier;
    message = e.message ?? null;
  }
  return { tier, message };
}

// Reps counted up to time t.
export function repsAt(events, t) {
  return events.filter((e) => e.type === "rep" && e.t <= t).length;
}

// At most `maxPoints` evenly spread samples for the chart (a long session has thousands).
export function chartPoints(motion, maxPoints = 600) {
  const n = motion.t.length;
  const step = Math.max(1, Math.ceil(n / maxPoints));
  const out = [];
  for (let i = 0; i < n; i += step) out.push({ t: motion.t[i], angle: motion.angle[i] });
  if (n && out[out.length - 1].t !== motion.t[n - 1]) out.push({ t: motion.t[n - 1], angle: motion.angle[n - 1] });
  return out;
}

// "1:05" from seconds.
export function formatClock(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}
