import { describe, expect, it } from "vitest";
import { DEFAULT_REST_SECONDS, MAX_REST_SECONDS, MIN_REST_SECONDS, cleanRestSeconds } from "./restSeconds";

describe("cleanRestSeconds", () => {
  it("keeps a sensible value", () => {
    expect(cleanRestSeconds(45)).toBe(45);
    expect(cleanRestSeconds("90")).toBe(90);
    expect(cleanRestSeconds(44.6)).toBe(45);
  });

  it("clamps to the allowed range", () => {
    expect(cleanRestSeconds(3)).toBe(MIN_REST_SECONDS);
    expect(cleanRestSeconds(5000)).toBe(MAX_REST_SECONDS);
  });

  it("falls back to the default for blank, zero or non-numbers", () => {
    for (const v of ["", 0, -5, "abc", null, undefined, NaN]) {
      expect(cleanRestSeconds(v)).toBe(DEFAULT_REST_SECONDS);
    }
  });
});
