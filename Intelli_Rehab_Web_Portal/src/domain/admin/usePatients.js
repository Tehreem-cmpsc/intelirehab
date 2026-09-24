import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

export default function usePatients(clinicId) {
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (!clinicId) {
      setList([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from("patients")
      .select("*, physiotherapists(full_name)")
      .eq("clinic_id", clinicId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Failed to load patients:", error);
      setList([]);
    } else {
      setList(data ?? []);
    }
    setLoading(false);
  }, [clinicId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { list, loading, refresh };
}
