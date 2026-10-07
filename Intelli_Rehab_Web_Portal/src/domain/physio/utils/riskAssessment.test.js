import { describe, expect, it } from "vitest";
import {
  DEFAULT_RISK_SETTINGS,
  SEVERITY,
  assessRisk,
  assessRiskDetailed,
  normalizeRiskSettings,
  riskSeverity,
} from "./riskAssessment";

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
    expect(assessRisk([session(0), unsafe(10)], NOW)).toEqual([]);
  });

  it("flags a high self-reported pain rating in the last 7 days, not a mild or an old one", () => {
    expect(assessRisk([session(1, { pain_level: 8 })], NOW)).toEqual(["Pain rated 8/10 in the last 7 days"]);
    expect(assessRisk([session(1, { pain_level: 7 })], NOW)).toEqual(["Pain rated 7/10 in the last 7 days"]);
    expect(assessRisk([session(1, { pain_level: 6 })], NOW)).toEqual([]);
    expect(assessRisk([session(1, { pain_level: null })], NOW)).toEqual([]);
    expect(assessRisk([session(0), session(10, { pain_level: 9 })], NOW)).toEqual([]);
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

  it("ignores sessions up to the moment a warning was sent, and counts later ones", () => {
    const unsafe = (d) => session(d, { movement_analysis: [{ posture_status: "unsafe" }] });
    const warnedAt = daysAgo(1);
    expect(assessRisk([unsafe(2)], NOW, warnedAt)).toEqual([]);
    expect(assessRisk([unsafe(0.5), unsafe(2)], NOW, warnedAt)).toEqual(["Unsafe movement in the last 7 days"]);
    expect(assessRisk([unsafe(2)], NOW, null)).toEqual(["Unsafe movement in the last 7 days"]);
    expect(assessRisk([unsafe(2)], NOW, "not a date")).toEqual(["Unsafe movement in the last 7 days"]);
  });

  it("flags a patient who has gone quiet, not one who just exercised, and not one who never has", () => {
    expect(assessRisk([session(9)], NOW)).toEqual(["No session for 9 days"]);
    expect(assessRisk([session(6)], NOW)).toEqual([]);
    expect(assessRisk([], NOW)).toEqual([]);
  });

  it("counts quiet days from the warning when that came after the last session", () => {
    expect(assessRisk([session(20)], NOW, daysAgo(9))).toEqual(["No session for 9 days since the warning"]);
    expect(assessRisk([session(20)], NOW, daysAgo(2))).toEqual([]);
  });

  it("uses the clinic's own thresholds when given", () => {
    const strict = { highPain: 4, inactiveDays: 3 };
    expect(assessRisk([session(1, { pain_level: 5 })], NOW, null, strict)).toEqual(["Pain rated 5/10 in the last 7 days"]);
    expect(assessRisk([session(1, { pain_level: 5 })], NOW)).toEqual([]);
    expect(assessRisk([session(4)], NOW, null, strict)).toEqual(["No session for 4 days"]);
    expect(assessRisk([session(4)], NOW)).toEqual([]);
  });

  it("gives each reason a severity, with unsafe movement and pain the highest", () => {
    const worst = assessRiskDetailed([session(1, { pain_level: 9, movement_analysis: [{ posture_status: "unsafe" }] })], NOW);
    expect(worst.map((r) => r.severity)).toEqual([SEVERITY.UNSAFE, SEVERITY.PAIN]);
    expect(riskSeverity(worst)).toBe(3);
    expect(riskSeverity(assessRiskDetailed([session(9)], NOW))).toBe(SEVERITY.INACTIVE);
    expect(riskSeverity([])).toBe(0);
  });

  it("cleans up stored settings: missing, partial and out-of-range values fall back one by one", () => {
    expect(normalizeRiskSettings(null)).toEqual(DEFAULT_RISK_SETTINGS);
    expect(normalizeRiskSettings({ highPain: 5, inactiveDays: 500, romDropPoints: "x", unsafeWindowDays: 2.5 })).toEqual({
      ...DEFAULT_RISK_SETTINGS,
      highPain: 5,
    });
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
