import { describe, expect, it } from "vitest";
import { chartPoints, formatClock, poseAt, repsAt, sampleIndexAt, tierAt } from "./motionReplay";

const motion = {
  t: [0, 1, 2, 3],
  angle: [0, 40, 90, 10],
  emg: [0, 20, 60, 5],
};

describe("motion replay helpers", () => {
  it("finds the sample at or before a time", () => {
    expect(sampleIndexAt(motion.t, -1)).toBe(-1);
    expect(sampleIndexAt(motion.t, 0)).toBe(0);
    expect(sampleIndexAt(motion.t, 1.5)).toBe(1);
    expect(sampleIndexAt(motion.t, 9)).toBe(3);
  });

  it("interpolates the pose between samples and holds it at the ends", () => {
    expect(poseAt(motion, 1.5)).toEqual({ angle: 65, emg: 40 });
    expect(poseAt(motion, -2).angle).toBe(0);
    expect(poseAt(motion, 10).angle).toBe(10);
  });

  it("reports the safety state in force, including going back to normal", () => {
    const events = [
      { type: "rep", t: 1 },
      { type: "tier", t: 2, tier: "unsafe", message: "Stop" },
      { type: "tier", t: 4, tier: "normal" },
    ];
    expect(tierAt(events, 1).tier).toBe("normal");
    expect(tierAt(events, 2.5)).toEqual({ tier: "unsafe", message: "Stop" });
    expect(tierAt(events, 5)).toEqual({ tier: "normal", message: null });
    expect(repsAt(events, 0.5)).toBe(0);
    expect(repsAt(events, 1)).toBe(1);
  });

  it("thins long recordings for the chart but keeps the last sample", () => {
    const n = 2000;
    const long = { t: Array.from({ length: n }, (_, i) => i / 15), angle: Array.from({ length: n }, () => 1) };
    const pts = chartPoints(long, 600);
    expect(pts.length).toBeLessThanOrEqual(601);
    expect(pts[pts.length - 1].t).toBe(long.t[n - 1]);
  });

  it("formats a clock", () => {
    expect(formatClock(65.4)).toBe("1:05");
    expect(formatClock(0)).toBe("0:00");
  });
});
