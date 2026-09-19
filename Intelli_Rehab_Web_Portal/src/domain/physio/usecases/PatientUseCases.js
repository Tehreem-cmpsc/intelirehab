import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const PatientUseCases = {
  async getAllPatients() {
    const { data, error } = await supabase
      .from("patients")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Error fetching patients:", error);
      throw error;
    }

    return data;
  },
};

export default PatientUseCases;