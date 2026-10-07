import { describe, expect, it } from "vitest";
import { FREQUENCIES, MAX_TEMPLATE_NAME, cleanTemplateName, exercisesFromRows, rowsFromTemplate } from "./planTemplates";

const catalogue = [{ id: "e1" }, { id: "e2" }, { id: "e3" }];
const key = (() => {
  let n = 0;
  return () => `k${++n}`;
})();

describe("cleanTemplateName", () => {
  it("tidies spaces and keeps a normal name", () => {
    expect(cleanTemplateName("  Post-fracture   elbow, weeks 1-2 ")).toBe("Post-fracture elbow, weeks 1-2");
  });

  it("is null when there is nothing to save", () => {
    for (const v of ["", "   ", null, undefined]) expect(cleanTemplateName(v)).toBeNull();
  });

  it("cuts a long name to the limit", () => {
    expect(cleanTemplateName("x".repeat(200))).toHaveLength(MAX_TEMPLATE_NAME);
  });
});

describe("exercisesFromRows", () => {
  it("keeps only rows with an exercise chosen, and keeps every setting", () => {
    const out = exercisesFromRows([
      { key: "a", exerciseId: "e1", sets: 3, reps: 10, romTarget: 70, frequency: "Daily", restSeconds: 45 },
      { key: "b", exerciseId: "", sets: 3, reps: 10, romTarget: 70, frequency: "Daily", restSeconds: 30 },
    ]);
    expect(out).toEqual([{ exerciseId: "e1", sets: 3, reps: 10, romTarget: 70, frequency: "Daily", restSeconds: 45 }]);
  });

  it("brings odd values inside the form's limits", () => {
    const [e] = exercisesFromRows([
      { exerciseId: "e1", sets: 99, reps: 0, romTarget: "abc", frequency: "Sometimes", restSeconds: 5000 },
    ]);
    expect(e).toEqual({ exerciseId: "e1", sets: 6, reps: 3, romTarget: 70, frequency: FREQUENCIES[0], restSeconds: 300 });
  });
});

describe("rowsFromTemplate", () => {
  const template = {
    name: "T",
    exercises: [
      { exerciseId: "e1", sets: 2, reps: 12, romTarget: 60, frequency: "Weekly", restSeconds: 60 },
      { exerciseId: "gone", sets: 3, reps: 10, romTarget: 70, frequency: "Daily", restSeconds: 30 },
      { exerciseId: "e3", sets: 3, reps: 10, romTarget: 80, frequency: "3× per week" },
    ],
  };

  it("turns a template into form rows, leaving out exercises that left the catalogue", () => {
    const { rows, dropped } = rowsFromTemplate(template, catalogue, key);
    expect(dropped).toBe(1);
    expect(rows.map((r) => r.exerciseId)).toEqual(["e1", "e3"]);
    expect(rows[0]).toMatchObject({ sets: 2, reps: 12, romTarget: 60, frequency: "Weekly", restSeconds: 60 });
    expect(new Set(rows.map((r) => r.key)).size).toBe(2);
  });

  it("gives an exercise saved without a rest length the default", () => {
    const { rows } = rowsFromTemplate(template, catalogue, key);
    expect(rows[1].restSeconds).toBe(30);
  });

  it("keeps an exercise once even if the template lists it twice", () => {
    const { rows, dropped } = rowsFromTemplate(
      { exercises: [{ exerciseId: "e1" }, { exerciseId: "e1" }] },
      catalogue,
      key
    );
    expect(rows).toHaveLength(1);
    expect(dropped).toBe(1);
  });

  it("copes with a template that is empty or damaged", () => {
    expect(rowsFromTemplate(null, catalogue, key)).toEqual({ rows: [], dropped: 0 });
    expect(rowsFromTemplate({ exercises: "nope" }, catalogue, key)).toEqual({ rows: [], dropped: 0 });
    expect(rowsFromTemplate({ exercises: [null, 5] }, catalogue, key).dropped).toBe(2);
  });

  it("is the inverse of exercisesFromRows for a normal plan", () => {
    const stored = [
      { exerciseId: "e1", sets: 2, reps: 12, romTarget: 60, frequency: "Weekly", restSeconds: 60 },
      { exerciseId: "e2", sets: 4, reps: 8, romTarget: 90, frequency: "Daily", restSeconds: 20 },
    ];
    const { rows } = rowsFromTemplate({ exercises: stored }, catalogue, key);
    expect(exercisesFromRows(rows)).toEqual(stored);
  });
});
