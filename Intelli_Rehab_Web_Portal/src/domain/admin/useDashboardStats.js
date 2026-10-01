import { useState, useEffect } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

export default function useDashboardStats(clinicId) {
  const [stats, setStats] = useState(null);

  useEffect(() => {
    if (!clinicId) {
      setStats(null);
      return;
    }
    (async () => {
      const { count: physios, error } = await supabase
        .from("physiotherapists")
        .select("*", { count: "exact", head: true })
        .eq("clinic_id", clinicId);

      if (error) console.error("Failed to load dashboard stats:", error);

      // Patients / sessions / avg. ROM aren't wired to real data yet — the
      // `patients` table's link back to a clinic isn't confirmed, and
      // there's no sessions table at all. `null` here means "not tracked
      // yet" rather than a real zero.
      setStats({
        physios: physios ?? 0,
        patients: null,
        sessionsToday: null,
        avgRom: null,
        error: error ? "Couldn't load clinic stats." : null,
      });
    })();
  }, [clinicId]);

  return stats;
}
