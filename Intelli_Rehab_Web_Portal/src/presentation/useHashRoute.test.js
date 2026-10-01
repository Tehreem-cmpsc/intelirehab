import { describe, it, expect } from "vitest";
import { parseHash } from "./useHashRoute";

describe("parseHash", () => {
  it("is empty for no hash or the landing page", () => {
    expect(parseHash("")).toEqual([]);
    expect(parseHash("#/")).toEqual([]);
  });
  it("splits app paths into segments", () => {
    expect(parseHash("#/app/patients/abc-123")).toEqual(["app", "patients", "abc-123"]);
  });
  it("decodes encoded segments", () => {
    expect(parseHash("#/app/patients/a%20b")).toEqual(["app", "patients", "a b"]);
  });
  it("ignores Supabase auth-redirect hashes", () => {
    expect(parseHash("#access_token=abc&type=recovery")).toEqual([]);
  });
  it("survives malformed escapes", () => {
    expect(() => parseHash("#/app/%E0%A4%A")).not.toThrow();
  });
});
