import { useState, useEffect } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

const AVG_ROM_DAYS = 30;
const MAX_ROWS = 5000;

// Numbers for the admin overview. RLS already limits every query to the admin's own
// clinic, so the only explicit clinic filter is on the tables that carry clinic_id.
// Exercise sessions only: the onboarding baseline is a session with no exercise.
export default function useDashboardStats(clinicId) {
  const [stats, setStats] = useState(null);

  useEffect(() => {
    if (!clinicId) {
      setStats(null);
      return;
    }
    let mounted = true;
    (async () => {
      const startOfToday = new Date();
      startOfToday.setHours(0, 0, 0, 0);
      const since = new Date(Date.now() - AVG_ROM_DAYS * 86400000).toISOString();

      const [physios, patients, today, recent] = await Promise.all([
        supabase.from("physiotherapists").select("*", { count: "exact", head: true }).eq("clinic_id", clinicId),
        supabase
          .from("patients")
          .select("*", { count: "exact", head: true })
          .eq("clinic_id", clinicId)
          .eq("approved", true),
        supabase
          .from("sessions")
          .select("*", { count: "exact", head: true })
          .not("exercise_id", "is", null)
          .gte("performed_at", startOfToday.toISOString()),
        supabase
          .from("sessions")
          .select("rom")
          .not("exercise_id", "is", null)
          .not("rom", "is", null)
          .gte("performed_at", since)
          .limit(MAX_ROWS),
      ]);

      const error = physios.error || patients.error || today.error || recent.error;
      if (error) console.error("Failed to load dashboard stats:", error);

      const roms = (recent.data ?? []).map((r) => r.rom);
      if (!mounted) return;
      setStats({
        physios: physios.count ?? 0,
        patients: patients.error ? null : patients.count ?? 0,
        sessionsToday: today.error ? null : today.count ?? 0,
        avgRom: recent.error ? null : roms.length ? Math.round(roms.reduce((a, b) => a + b, 0) / roms.length) : null,
        error: error ? "Couldn't load some clinic stats." : null,
      });
    })();
    return () => {
      mounted = false;
    };
  }, [clinicId]);

  return stats;
}
