import { describe, expect, it } from "vitest";
import { FOLLOW_UP_DAYS, ageLabel, daysSince } from "./warnings";

const NOW = new Date("2026-10-07T12:00:00Z");

describe("warning age", () => {
  it("counts whole days, never negative, and null for an untimed warning", () => {
    expect(daysSince(new Date("2026-10-07T08:00:00Z"), NOW)).toBe(0);
    expect(daysSince(new Date("2026-10-04T11:00:00Z"), NOW)).toBe(3);
    expect(daysSince(new Date("2026-10-09T00:00:00Z"), NOW)).toBe(0);
    expect(daysSince(null, NOW)).toBeNull();
  });

  it("says it in plain words", () => {
    expect(ageLabel(0)).toBe("today");
    expect(ageLabel(1)).toBe("yesterday");
    expect(ageLabel(4)).toBe("4 days ago");
    expect(ageLabel(null)).toBe("");
  });

  it("nudges a follow-up after a few days", () => {
    expect(FOLLOW_UP_DAYS).toBeGreaterThan(0);
  });
});
