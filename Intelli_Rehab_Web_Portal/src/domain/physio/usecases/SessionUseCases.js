import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const SessionUseCases = {
  // Every session the current physio/admin can see under RLS — already
  // scoped to their clinic's patients server-side, so no explicit
  // clinic_id/patient_id filter is needed here. Fetched once and shared
  // across the patient list (per-patient rom/trend/streak) and the
  // dashboard (clinic-wide charts) rather than querying separately.
  // movement_analysis comes along so PatientUseCases can tell the mobile
  // app's onboarding calibration (posture_status = 'baseline_calibration')
  // apart from exercise sessions.
  async getAllSessions() {
    const { data, error } = await supabase
      .from("sessions")
      .select(
        "id, patient_id, performed_at, rom, quality, fatigue, reps, exercises(name), movement_analysis(posture_status, joint_angle, rom)"
      )
      .order("performed_at", { ascending: false });

    if (error) {
      console.error("Error fetching sessions:", error);
      throw error;
    }
    return data ?? [];
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
