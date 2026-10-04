import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

export default function usePatients(clinicId) {
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const refresh = useCallback(async () => {
    if (!clinicId) {
      setList([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);

    // Physiotherapist names are joined here rather than with a PostgREST embed
    // (physiotherapists(full_name)): an embed fails outright if the database ever has
    // more than one relationship between the two tables, and takes the whole list with it.
    const [patientsRes, physiosRes] = await Promise.all([
      supabase.from("patients").select("*").eq("clinic_id", clinicId).order("created_at", { ascending: false }),
      supabase.from("physiotherapists").select("id, full_name").eq("clinic_id", clinicId),
    ]);

    if (patientsRes.error) {
      console.error("Failed to load patients:", patientsRes.error);
      setError("Unable to load this data. Check your connection and try again.");
      setList([]);
    } else {
      // A failed name lookup only costs the names ("Unassigned"), not the list.
      if (physiosRes.error) console.error("Failed to load physiotherapist names:", physiosRes.error);
      const names = new Map((physiosRes.data ?? []).map((p) => [p.id, p.full_name]));
      setList(
        (patientsRes.data ?? []).map((p) => ({
          ...p,
          physiotherapists: names.has(p.physio_id) ? { full_name: names.get(p.physio_id) } : null,
        }))
      );
    }
    setLoading(false);
  }, [clinicId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { list, loading, error, refresh };
}
