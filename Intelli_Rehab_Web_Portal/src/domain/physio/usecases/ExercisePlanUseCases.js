import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const today = () => new Date().toISOString().slice(0, 10);

const ExercisePlanUseCases = {
  // The patient's current active plan, grouped the way the mobile app's
  // Exercises tab (PlanListScreen) shows it to the patient — a plan name
  // plus every active exercise on it — so the physio sees exactly what
  // the patient sees.
  async getActivePlan(patientId) {
    const [{ data: planRow, error: planError }, { data: exerciseRows, error: exError }] = await Promise.all([
      supabase
        .from("rehabilitation_plans")
        .select("id, plan_name, start_date")
        .eq("patient_id", patientId)
        .eq("status", "active")
        .order("start_date", { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from("patient_exercise_plans")
        .select("id, exercise_id, sets, reps, rom_target, frequency, exercises(name, target, difficulty)")
        .eq("patient_id", patientId)
        .eq("active", true),
    ]);
    if (planError) throw planError;
    if (exError) throw exError;

    return {
      planName: planRow?.plan_name ?? null,
      startDate: planRow?.start_date ?? null,
      exercises: (exerciseRows ?? []).map((r) => ({
        assignmentId: r.id,
        exerciseId: r.exercise_id,
        name: r.exercises?.name ?? "Exercise",
        target: r.exercises?.target ?? null,
        difficulty: r.exercises?.difficulty ?? null,
        sets: r.sets,
        reps: r.reps,
        romTarget: r.rom_target,
        frequency: r.frequency,
      })),
    };
  },

  // Assigning a session replaces whatever was previously active — a
  // physio revising a patient's exercises should end up with exactly
  // what they just set, not a growing pile of every exercise ever
  // assigned. New rows are written before the old ones are retired, so a
  // failure partway through never leaves the patient with nothing
  // assigned (see the try/catch below).
  async assignSession({ patientId, physioId, planName, exercises }) {
    if (!exercises?.length) throw new Error("Select at least one exercise.");

    // Captured before writing anything, so retiring "the old assignment"
    // afterwards is an exact `IN (these ids)` — never a `NOT IN` on a
    // nullable column, which silently skips NULL rows in Postgres.
    const [{ data: oldExerciseRows }, { data: oldPlanRows }] = await Promise.all([
      supabase.from("patient_exercise_plans").select("id").eq("patient_id", patientId).eq("active", true),
      supabase.from("rehabilitation_plans").select("id").eq("patient_id", patientId).eq("status", "active"),
    ]);

    const { data: plan, error: planError } = await supabase
      .from("rehabilitation_plans")
      .insert({
        patient_id: patientId,
        physio_id: physioId,
        plan_name: (planName || "").trim() || "Exercise session",
        start_date: today(),
        status: "active",
      })
      .select("id")
      .single();
    if (planError) throw planError;

    const { error: insertError } = await supabase.from("patient_exercise_plans").insert(
      exercises.map((ex) => ({
        patient_id: patientId,
        exercise_id: ex.exerciseId,
        assigned_by: physioId,
        plan_id: plan.id,
        sets: ex.sets,
        reps: ex.reps,
        rom_target: ex.romTarget,
        frequency: ex.frequency,
        active: true,
      }))
    );
    if (insertError) {
      // The new plan has no exercises attached — don't leave it "active"
      // fighting the still-genuinely-active old one for FR-11's
      // most-recent-by-start_date lookup.
      await supabase.from("rehabilitation_plans").delete().eq("id", plan.id);
      throw insertError;
    }

    const oldExerciseIds = (oldExerciseRows ?? []).map((r) => r.id);
    if (oldExerciseIds.length) {
      await supabase.from("patient_exercise_plans").update({ active: false }).in("id", oldExerciseIds);
    }
    const oldPlanIds = (oldPlanRows ?? []).map((r) => r.id);
    if (oldPlanIds.length) {
      await supabase.from("rehabilitation_plans").update({ status: "completed", end_date: today() }).in("id", oldPlanIds);
    }
  },
};

export default ExercisePlanUseCases;
