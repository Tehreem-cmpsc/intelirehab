import { supabase } from "../../../infrastructure/supabase/supabaseClient";
import { Patient } from "../entities";
import SessionUseCases from "./SessionUseCases";
import { formatSessionForUi, computeStreak, computeWeeklyRom } from "../utils/sessionAnalytics";

// Maps a real `patients` row (+ that patient's real sessions, already
// fetched in bulk by getAllPatients) to the Patient entity the physio UI
// expects. rom/trend/streak/romWeekly all come from real session data now —
// a patient with no sessions yet correctly shows 0/empty rather than a
// fabricated number.
const toPatient = (row, sessionsForPatient) => {
  const sessionsDesc = sessionsForPatient
    .map(formatSessionForUi)
    .sort((a, b) => b.performedAt - a.performedAt);
  const sessionsAsc = [...sessionsDesc].reverse();

  const latestRom = sessionsDesc[0]?.rom ?? 0;
  const previousRom = sessionsDesc[1]?.rom;
  const trend = sessionsDesc.length >= 2 ? latestRom - previousRom : 0;

  return new Patient({
    id: row.id,
    name: row.name,
    regId: row.reg_id,
    injury: row.injury,
    rom: latestRom,
    trend,
    streak: computeStreak(sessionsDesc),
    status: row.status,
    wearable: row.wearable_connected,
    approved: row.approved,
    warning: row.warning,
    sessions: sessionsDesc,
    romWeekly: computeWeeklyRom(sessionsAsc),
  });
};

const PatientUseCases = {
  async getAllPatients() {
    const [{ data: patientRows, error: patientsError }, allSessions] = await Promise.all([
      supabase.from("patients").select("*").order("created_at", { ascending: false }),
      SessionUseCases.getAllSessions(),
    ]);

    if (patientsError) {
      console.error("Error fetching patients:", patientsError);
      throw patientsError;
    }

    const sessionsByPatient = new Map();
    for (const session of allSessions) {
      if (!sessionsByPatient.has(session.patient_id)) sessionsByPatient.set(session.patient_id, []);
      sessionsByPatient.get(session.patient_id).push(session);
    }

    return (patientRows ?? []).map((row) => toPatient(row, sessionsByPatient.get(row.id) ?? []));
  },
};

export default PatientUseCases;
