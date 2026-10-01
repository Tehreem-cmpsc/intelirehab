import { describe, it, expect } from "vitest";
import { wearableState } from "../../../domain/physio/utils/patientLabels";

describe("wearableState", () => {
  it("is live only when connected right now", () => {
    expect(wearableState({ wearable: true, wearableLive: true })).toBe("live");
  });
  it("paired but not live is offline - never 'connected'", () => {
    expect(wearableState({ wearable: true, wearableLive: false })).toBe("offline");
  });
  it("no paired band is none", () => {
    expect(wearableState({ wearable: false, wearableLive: false })).toBe("none");
  });
});
