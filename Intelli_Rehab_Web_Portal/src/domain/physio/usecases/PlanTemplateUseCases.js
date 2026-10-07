import { supabase } from "../../../infrastructure/supabase/supabaseClient";
import { cleanTemplateName } from "../utils/planTemplates";

// The table arrives with supabase_plan_templates.sql; until it has been run, templates are simply unavailable.
const isMissingTable = (error) => error?.code === "42P01" || error?.code === "PGRST205";

const PlanTemplateUseCases = {
  // The clinic's templates (RLS already limits them to the signed-in physiotherapist's clinic), by name.
  // An empty list - not an error - when the table has not been created yet.
  async list() {
    const { data, error } = await supabase
      .from("plan_templates")
      .select("id, name, exercises, created_at")
      .order("name", { ascending: true });
    if (error) {
      if (isMissingTable(error)) return [];
      console.error("Error loading plan templates:", error);
      throw error;
    }
    return data ?? [];
  },

  async save({ clinicId, physioId, name, exercises }) {
    const clean = cleanTemplateName(name);
    if (!clean) throw new Error("Give the template a name.");
    if (!exercises?.length) throw new Error("Choose at least one exercise to save.");
    if (!clinicId) throw new Error("Your clinic could not be found, so the template was not saved.");
    const { data, error } = await supabase
      .from("plan_templates")
      .insert({ clinic_id: clinicId, created_by: physioId ?? null, name: clean, exercises })
      .select("id, name, exercises, created_at")
      .single();
    if (error) {
      if (error.code === "23505") throw new Error("A template with that name already exists. Pick another name.");
      if (isMissingTable(error)) {
        throw new Error("Templates need the latest database update (supabase_plan_templates.sql).");
      }
      throw new Error(error.message || "Couldn't save the template.");
    }
    return data;
  },

  // RLS silently matches zero rows for a template that is not the caller's clinic's, so .select() tells
  // "removed" from "not allowed".
  async remove(id) {
    const { data, error } = await supabase.from("plan_templates").delete().eq("id", id).select("id");
    if (error) throw new Error(error.message || "Couldn't delete the template.");
    if (!data?.length) throw new Error("That template could not be deleted.");
  },
};

export default PlanTemplateUseCases;
