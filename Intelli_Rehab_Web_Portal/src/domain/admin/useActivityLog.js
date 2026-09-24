import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

// Real replacement for the old MOCK_DB-backed useActivity.js (removed
// earlier this session as dead code). Matches what the SDD's Figure 19
// mockup shows — a real recent-activity feed, not a static placeholder.
export default function useActivityLog(clinicId) {
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
      .from("activity_log")
      .select("*")
      .eq("clinic_id", clinicId)
      .order("created_at", { ascending: false })
      .limit(10);

    if (error) {
      console.error("Failed to load activity log:", error);
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
