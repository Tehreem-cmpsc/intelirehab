// A warning that has been sent but not yet followed by a session is "still open". After this many days
// the physio is nudged to follow up themselves.
export const FOLLOW_UP_DAYS = 3;

const DAY_MS = 86400000;

// Whole days from `date` to `now`; null when there is no date (e.g. a warning sent before warnings were timed).
export const daysSince = (date, now = new Date()) =>
  date ? Math.max(0, Math.floor((now.getTime() - date.getTime()) / DAY_MS)) : null;

export const ageLabel = (days) =>
  days === null ? "" : days === 0 ? "today" : days === 1 ? "yesterday" : `${days} days ago`;
