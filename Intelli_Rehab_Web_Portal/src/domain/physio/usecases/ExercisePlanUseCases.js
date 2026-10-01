import { supabase } from "../../../infrastructure/supabase/supabaseClient";
import { localDateString } from "../utils/sessionAnalytics";

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

  // Assigning a session replaces whatever was previously active - a physio
  // revising a patient's exercises should end up with exactly what they just
  // set. Done in one database transaction (assign_exercise_session, see
  // supabase_assign_session_rpc.sql), so it either fully happens or not at
  // all - never two active plans, never a patient left with nothing.
  async assignSession({ patientId, physioId, planName, exercises }) {
    if (!exercises?.length) throw new Error("Select at least one exercise.");

    const { error } = await supabase.rpc("assign_exercise_session", {
      p_patient_id: patientId,
      p_physio_id: physioId,
      p_plan_name: planName || "",
      p_start_date: localDateString(),
      p_exercises: exercises.map((ex) => ({
        exerciseId: ex.exerciseId,
        sets: ex.sets,
        reps: ex.reps,
        romTarget: ex.romTarget,
        frequency: ex.frequency,
      })),
    });
    if (error) throw new Error(error.message || "Couldn't assign this session.");
  },
};

export default ExercisePlanUseCases;
