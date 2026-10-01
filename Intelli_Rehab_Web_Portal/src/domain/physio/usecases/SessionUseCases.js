import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const HISTORY_DAYS = 90;
const MAX_ROWS = 5000;
const BASELINE_MARKER = "baseline_calibration";
const SESSION_COLUMNS =
  "id, patient_id, performed_at, rom, quality, fatigue, reps, exercises(name), movement_analysis(posture_status, joint_angle, rom)";

const SessionUseCases = {
  // Every session the current physio/admin can see under RLS — already
  // scoped to their clinic's patients server-side, so no explicit
  // clinic_id/patient_id filter is needed here. Fetched once and shared
  // across the patient list (per-patient rom/trend/streak) and the
  // dashboard (clinic-wide charts) rather than querying separately.
  // movement_analysis comes along so PatientUseCases can tell the mobile
  // app's onboarding calibration (posture_status = 'baseline_calibration')
  // apart from exercise sessions.
  //
  // Bounded so the 60 s portal refresh doesn't pull a clinic's entire
  // history: the last HISTORY_DAYS of sessions (plenty for trend, streak
  // and the weekly charts), plus each patient's onboarding baseline
  // however old it is. PostgREST's own max-rows setting may cap this
  // further; raise it in the Supabase API settings if a clinic outgrows it.
  async getAllSessions() {
    const since = new Date(Date.now() - HISTORY_DAYS * 86400000).toISOString();

    const [recent, baselines] = await Promise.all([
      supabase
        .from("sessions")
        .select(SESSION_COLUMNS)
        .gte("performed_at", since)
        .order("performed_at", { ascending: false })
        .limit(MAX_ROWS),
      supabase
        .from("sessions")
        .select(SESSION_COLUMNS.replace("movement_analysis(", "movement_analysis!inner("))
        .eq("movement_analysis.posture_status", BASELINE_MARKER)
        .order("performed_at", { ascending: false })
        .limit(MAX_ROWS),
    ]);

    const error = recent.error || baselines.error;
    if (error) {
      console.error("Error fetching sessions:", error);
      throw error;
    }

    const byId = new Map();
    for (const row of [...(baselines.data ?? []), ...(recent.data ?? [])]) byId.set(row.id, row);
    return [...byId.values()];
  },

  // EMG is only ever shown for whichever one patient's detail view is
  // open, so it's fetched on demand rather than bulk-loaded with everyone
  // else's sessions.
  async getLatestEmgForPatient(patientId) {
    const { data: latestSession, error: sessionErr } = await supabase
      .from("sessions")
      .select("id")
      .eq("patient_id", patientId)
      .order("performed_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (sessionErr) {
      console.error("Error finding latest session for EMG:", sessionErr);
      throw sessionErr;
    }
    if (!latestSession) return [];

    const { data: emgRows, error: emgErr } = await supabase
      .from("emg_readings")
      .select("muscle, value")
      .eq("session_id", latestSession.id);

    if (emgErr) {
      console.error("Error fetching EMG readings:", emgErr);
      throw emgErr;
    }
    return (emgRows ?? []).map((r) => ({ muscle: r.muscle, val: r.value }));
  },
};

export default SessionUseCases;
