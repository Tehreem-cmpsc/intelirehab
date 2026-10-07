import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const HISTORY_DAYS = 90;
const MAX_ROWS = 5000;
const BASELINE_MARKER = "baseline_calibration";
const SESSION_COLUMNS =
  "id, patient_id, performed_at, rom, quality, fatigue, reps, exercises(name), movement_analysis(posture_status, joint_angle, rom)";
// pain_level / ended_reason arrive with supabase_session_module_v2.sql; until it has been run the
// portal must keep working, so a "column does not exist" error falls back to the plain columns.
const SESSION_COLUMNS_V2 = SESSION_COLUMNS.replace("reps,", "reps, pain_level, ended_reason,");
const isMissingColumn = (error) => error?.code === "42703" || error?.code === "PGRST204";

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

    const fetchBoth = (columns) =>
      Promise.all([
        supabase
          .from("sessions")
          .select(columns)
          .gte("performed_at", since)
          .order("performed_at", { ascending: false })
          .limit(MAX_ROWS),
        supabase
          .from("sessions")
          .select(columns.replace("movement_analysis(", "movement_analysis!inner("))
          .eq("movement_analysis.posture_status", BASELINE_MARKER)
          .order("performed_at", { ascending: false })
          .limit(MAX_ROWS),
      ]);

    let [recent, baselines] = await fetchBoth(SESSION_COLUMNS_V2);
    if (isMissingColumn(recent.error) || isMissingColumn(baselines.error)) {
      [recent, baselines] = await fetchBoth(SESSION_COLUMNS);
    }

    const error = recent.error || baselines.error;
    if (error) {
      console.error("Error fetching sessions:", error);
      throw error;
    }

    const byId = new Map();
    for (const row of [...(baselines.data ?? []), ...(recent.data ?? [])]) byId.set(row.id, row);
    return [...byId.values()];
  },

  // The movement the band recorded during one session (supabase_session_motion.sql), for the replay.
  // null when there is none: an older app version, a simulated session, or the table not created yet.
  async getMotion(sessionId) {
    const { data, error } = await supabase
      .from("session_motion")
      .select("sample_rate_hz, side, t_ms, angle, emg, events")
      .eq("session_id", sessionId)
      .maybeSingle();
    if (error) {
      // 42P01 / PGRST205: the table has not been created yet - same as "no recording".
      if (error.code === "42P01" || error.code === "PGRST205") return null;
      console.error("Error loading session motion:", error);
      throw error;
    }
    if (!data || !data.t_ms?.length) return null;
    return {
      sampleRateHz: data.sample_rate_hz,
      side: data.side === "right" ? "right" : "left",
      t: data.t_ms.map((ms) => ms / 1000), // seconds
      angle: data.angle,
      emg: data.emg,
      events: (data.events ?? []).map((e) => ({ ...e, t: (e.t_ms ?? 0) / 1000 })),
    };
  },

  // The per-set breakdown of one session (supabase_session_module_v2.sql), oldest set first. An empty
  // list when there is none: an older app version, a one-set session, or the table not created yet.
  async getSets(sessionId) {
    const { data, error } = await supabase
      .from("session_sets")
      .select("set_number, reps, rom, corrections, unsafe, fatigue")
      .eq("session_id", sessionId)
      .order("set_number", { ascending: true });
    if (error) {
      if (error.code === "42P01" || error.code === "PGRST205") return [];
      console.error("Error loading session sets:", error);
      throw error;
    }
    return (data ?? []).map((s) => ({
      number: s.set_number,
      reps: s.reps,
      rom: s.rom,
      corrections: s.corrections,
      unsafe: s.unsafe,
      fatigue: s.fatigue,
    }));
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
