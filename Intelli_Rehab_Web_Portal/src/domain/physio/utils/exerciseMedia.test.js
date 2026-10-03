import { describe, expect, it } from "vitest";
import { resolveMediaUrl } from "./exerciseMedia";

describe("resolveMediaUrl", () => {
  it("serves a relative path from the portal root", () => {
    expect(resolveMediaUrl("exercises/hammer-curl.webp")).toBe("/exercises/hammer-curl.webp");
    expect(resolveMediaUrl("/exercises/hammer-curl.webp")).toBe("/exercises/hammer-curl.webp");
    expect(resolveMediaUrl("exercises/hammer-curl.webp", "/portal")).toBe("/portal/exercises/hammer-curl.webp");
  });

  it("passes an https URL through", () => {
    expect(resolveMediaUrl("https://cdn.example.com/curl.mp4")).toBe("https://cdn.example.com/curl.mp4");
  });

  it("refuses anything that is not a plain path or https URL", () => {
    for (const bad of [
      "javascript:alert(1)",
      "data:image/svg+xml,<svg/>",
      "http://example.com/a.webp",
      "//evil.example.com/a.webp",
      "../secrets.webp",
      "exercises/../../x.webp",
      "",
      "   ",
      null,
      undefined,
      42,
    ]) {
      expect(resolveMediaUrl(bad), String(bad)).toBeNull();
    }
  });
});
