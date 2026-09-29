import { supabase } from "../../supabase/supabaseClient";
import { Exercise } from "../../../domain/physio/entities";

// Real `exercises` table (seeded by supabase_seed_exercises.sql) — this
// used to wrap the mock array in constants/mockData.js; assigning a real
// session needs a real exercise_id (patient_exercise_plans.exercise_id is
// a uuid FK), so both this and the Exercise Database tab now read the
// same live catalogue instead of two different lists.
class ExerciseRepository {
  async getAll() {
    const { data, error } = await supabase
      .from("exercises")
      .select("id, name, target, difficulty, description")
      .order("name");
    if (error) {
      console.error("Error fetching exercises:", error);
      throw error;
    }
    return (data ?? []).map(
      (r) => new Exercise({ id: r.id, name: r.name, target: r.target ?? "", difficulty: r.difficulty, desc: r.description ?? "" })
    );
  }

  filter(exercises, difficulty, query) {
    let filtered = exercises;
    if (difficulty !== "All") filtered = filtered.filter((e) => e.isDifficulty(difficulty));
    if (query) filtered = filtered.filter((e) => e.matches(query));
    return filtered;
  }
}

export default new ExerciseRepository();
