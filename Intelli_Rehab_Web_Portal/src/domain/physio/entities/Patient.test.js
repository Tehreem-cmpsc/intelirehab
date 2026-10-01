import { describe, it, expect } from "vitest";
import { Patient } from "./Patient";

const make = (over = {}) => new Patient({ id: "1", name: "A", status: "at-risk", approved: false, ...over });

describe("Patient.with", () => {
  it("returns a copy with the changes, leaving the original untouched", () => {
    const p = make();
    const q = p.with({ approved: true });
    expect(q.approved).toBe(true);
    expect(p.approved).toBe(false);
  });
  it("keeps the class and its methods (a plain spread would not)", () => {
    const q = make().with({ approved: true });
    expect(q).toBeInstanceOf(Patient);
    expect(q.isAtRisk()).toBe(true);
    expect(q.isPendingApproval()).toBe(false);
  });
});
