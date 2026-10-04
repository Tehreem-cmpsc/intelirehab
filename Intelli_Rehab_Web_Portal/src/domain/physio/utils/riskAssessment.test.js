import { describe, expect, it } from "vitest";
import { assessRisk } from "./riskAssessment";

const NOW = new Date("2026-10-04T12:00:00Z");
const daysAgo = (d) => new Date(NOW.getTime() - d * 86400000).toISOString();
const session = (daysBack, over = {}) => ({ performed_at: daysAgo(daysBack), rom: 80, fatigue: 0, movement_analysis: [], ...over });

describe("assessRisk", () => {
  it("flags nothing for no sessions or steady sessions", () => {
    expect(assessRisk([], NOW)).toEqual([]);
    expect(assessRisk([session(0), session(1), session(2)], NOW)).toEqual([]);
  });

  it("flags an unsafe movement in the last 7 days, not an older one", () => {
    const unsafe = (d) => session(d, { movement_analysis: [{ posture_status: "unsafe" }] });
    expect(assessRisk([unsafe(2)], NOW)).toEqual(["Unsafe movement in the last 7 days"]);
    expect(assessRisk([unsafe(10)], NOW)).toEqual([]);
  });

  it("flags a steady ROM fall of 15+ points over the last 3 sessions", () => {
    const falling = [session(0, { rom: 55 }), session(1, { rom: 68 }), session(2, { rom: 75 })];
    expect(assessRisk(falling, NOW)).toEqual(["ROM fell 20 points over the last 3 sessions"]);
  });

  it("does not flag a small fall, a bounce, or fewer than 3 sessions", () => {
    expect(assessRisk([session(0, { rom: 70 }), session(1, { rom: 75 }), session(2, { rom: 80 })], NOW)).toEqual([]);
    expect(assessRisk([session(0, { rom: 50 }), session(1, { rom: 90 }), session(2, { rom: 70 })], NOW)).toEqual([]);
    expect(assessRisk([session(0, { rom: 40 }), session(1, { rom: 80 })], NOW)).toEqual([]);
  });

  it("flags critical fatigue in two sessions in a row, not one", () => {
    expect(assessRisk([session(0, { fatigue: 3 }), session(1, { fatigue: 3 })], NOW)).toEqual([
      "Critical fatigue in the last 2 sessions",
    ]);
    expect(assessRisk([session(0, { fatigue: 3 }), session(1, { fatigue: 1 })], NOW)).toEqual([]);
  });

  it("can give several reasons at once", () => {
    const sessions = [
      session(0, { rom: 50, fatigue: 3, movement_analysis: [{ posture_status: "unsafe" }] }),
      session(1, { rom: 65, fatigue: 3 }),
      session(2, { rom: 80 }),
    ];
    expect(assessRisk(sessions, NOW)).toHaveLength(3);
  });
});
