import { supabase } from "../../supabase/supabaseClient";
import { Exercise } from "../../../domain/physio/entities";

// Real `exercises` table (seeded by supabase_seed_exercises.sql) — this
// used to wrap the mock array in constants/mockData.js; assigning a real
// session needs a real exercise_id (patient_exercise_plans.exercise_id is
// a uuid FK), so both this and the Exercise Database tab now read the
// same live catalogue instead of two different lists.
class ExerciseRepository {
  async getAll() {
    const base = "id, name, target, difficulty, description";
    let { data, error } = await supabase.from("exercises").select(`${base}, media_url, media_type`).order("name");
    // The illustration columns come from supabase_exercise_media.sql. Until that has been run
    // the catalogue must still load, just without pictures, so retry without them.
    if (error && (error.code === "42703" || /media_(url|type)/.test(error.message ?? ""))) {
      ({ data, error } = await supabase.from("exercises").select(base).order("name"));
    }
    if (error) {
      console.error("Error fetching exercises:", error);
      throw error;
    }
    return (data ?? []).map(
      (r) =>
        new Exercise({
          id: r.id,
          name: r.name,
          target: r.target ?? "",
          difficulty: r.difficulty,
          desc: r.description ?? "",
          mediaUrl: r.media_url ?? null,
          mediaType: r.media_type === "video" ? "video" : "image",
        })
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
