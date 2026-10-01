import { describe, it, expect } from "vitest";
import {
  startOfWeek,
  computeStreak,
  computeWeeklyRom,
  computeWeekdayActivity,
  localDateString,
} from "./sessionAnalytics";

const daysAgo = (n, hour = 12) => {
  const d = new Date();
  d.setHours(hour, 0, 0, 0);
  d.setDate(d.getDate() - n);
  return d;
};
const session = (date, rom = 50) => ({ performedAt: date, rom });

describe("startOfWeek", () => {
  it("anchors on Monday at local midnight", () => {
    const wed = new Date(2026, 9, 7, 15, 30); // Wed 7 Oct 2026
    expect(startOfWeek(wed)).toEqual(new Date(2026, 9, 5, 0, 0, 0, 0));
  });
  it("treats Sunday as the end of the week, not the start", () => {
    const sun = new Date(2026, 9, 11, 9, 0); // Sun 11 Oct 2026
    expect(startOfWeek(sun)).toEqual(new Date(2026, 9, 5, 0, 0, 0, 0));
  });
});

describe("computeStreak", () => {
  it("is 0 with no sessions", () => {
    expect(computeStreak([])).toBe(0);
  });
  it("counts consecutive days ending today", () => {
    expect(computeStreak([session(daysAgo(0)), session(daysAgo(1)), session(daysAgo(2))])).toBe(3);
  });
  it("still counts when nothing is logged yet today", () => {
    expect(computeStreak([session(daysAgo(1)), session(daysAgo(2))])).toBe(2);
  });
  it("stops at the first gap", () => {
    expect(computeStreak([session(daysAgo(0)), session(daysAgo(2))])).toBe(1);
  });
  it("counts several sessions on one day once", () => {
    expect(computeStreak([session(daysAgo(0, 9)), session(daysAgo(0, 18))])).toBe(1);
  });
});

describe("computeWeeklyRom", () => {
  it("averages ROM per week, oldest first, labelled W1..", () => {
    const out = computeWeeklyRom([
      session(new Date(2026, 9, 5), 40),
      session(new Date(2026, 9, 6), 60),
      session(new Date(2026, 9, 12), 80),
    ]);
    expect(out).toEqual([
      { w: "W1", v: 50 },
      { w: "W2", v: 80 },
    ]);
  });
  it("keeps only the most recent weeks", () => {
    const sessions = Array.from({ length: 10 }, (_, i) => session(new Date(2026, 8, 1 + i * 7), i));
    expect(computeWeeklyRom(sessions, 6)).toHaveLength(6);
  });
});

describe("computeWeekdayActivity", () => {
  it("returns Mon..Sun and counts only this week's sessions", () => {
    const out = computeWeekdayActivity([session(daysAgo(60))]);
    expect(out.map((d) => d.day)).toEqual(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
    expect(out.every((d) => d.s === 0)).toBe(true);
  });
});

describe("localDateString", () => {
  it("uses the local calendar date, zero-padded", () => {
    expect(localDateString(new Date(2026, 0, 5, 23, 59))).toBe("2026-01-05");
  });
});
