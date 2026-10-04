import { supabase } from "../../../infrastructure/supabase/supabaseClient";
import { Patient } from "../entities";
import SessionUseCases from "./SessionUseCases";
import { formatSessionForUi, computeStreak, computeWeeklyRom } from "../utils/sessionAnalytics";
import { assessRisk } from "../utils/riskAssessment";

// The mobile app stores its onboarding calibration as a session whose
// movement_analysis row carries this marker (OnboardingRepository.baselineMarker).
const BASELINE_MARKER = "baseline_calibration";
const isBaseline = (session) =>
  (session.movement_analysis ?? []).some((m) => m.posture_status === BASELINE_MARKER);

const latestBy = (rows, key) =>
  [...(rows ?? [])].sort((a, b) => new Date(b[key]) - new Date(a[key]))[0] ?? null;

// Maps a real `patients` row (with its injuries + wearables embedded, and
// that patient's sessions, already fetched in bulk by getAllPatients) to the
// Patient entity the physio UI expects. rom/trend/streak/romWeekly come from
// exercise sessions only — the onboarding calibration is shown separately
// as `baseline` (it's measured in degrees, not the % used for ROM).
const toPatient = (row, sessionsForPatient) => {
  const exerciseSessions = sessionsForPatient.filter((s) => !isBaseline(s));
  const sessionsDesc = exerciseSessions
    .map(formatSessionForUi)
    .sort((a, b) => b.performedAt - a.performedAt);
  const sessionsAsc = [...sessionsDesc].reverse();

  // Nothing writes status = 'at-risk', so it is worked out from the sessions here. A status
  // someone set by hand ('recovered', or 'at-risk') is kept.
  const riskReasons = assessRisk(
    [...exerciseSessions].sort((a, b) => new Date(b.performed_at) - new Date(a.performed_at))
  );
  const status = row.status === "recovered" ? row.status : riskReasons.length ? "at-risk" : row.status;

  const latestRom = sessionsDesc[0]?.rom ?? 0;
  const previousRom = sessionsDesc[1]?.rom;
  const trend = sessionsDesc.length >= 2 ? latestRom - previousRom : 0;

  const injury = latestBy(row.patient_injuries, "created_at");
  const device = latestBy(
    (row.wearable_devices ?? []).filter((d) => d.status === "paired"),
    "created_at"
  );
  const baselineSession = latestBy(sessionsForPatient.filter(isBaseline), "performed_at");
  const baselineAnalysis = baselineSession?.movement_analysis.find((m) => m.posture_status === BASELINE_MARKER);

  return new Patient({
    id: row.id,
    name: row.name,
    regId: row.reg_id,
    injury: row.injury,
    rom: latestRom,
    trend,
    streak: computeStreak(sessionsDesc),
    status,
    riskReasons,
    // wearable_connected is kept in sync by a trigger
    // (supabase_patient_wearable_sync.sql); the device row is checked too
    // in case that trigger isn't installed.
    wearable: Boolean(row.wearable_connected || device),
    approved: row.approved,
    warning: row.warning,
    sessions: sessionsDesc,
    romWeekly: computeWeeklyRom(sessionsAsc),
    profile: {
      email: row.email || null,
      phone: row.phone || null,
      dateOfBirth: row.date_of_birth,
      gender: row.gender || null,
      activityLevel: row.activity_level,
      dominantArm: row.dominant_arm,
      physioId: row.physio_id,
      registeredAt: row.created_at,
      termsAcceptedAt: row.terms_accepted_at,
    },
    injuryDetails: injury && {
      side: injury.affected_side,
      joint: injury.affected_joint,
      type: injury.injury_type,
      cause: injury.cause,
      date: injury.diagnosis_date,
      firstInjury: injury.first_injury,
      painLevel: injury.pain_level,
      notes: injury.description,
    },
    device: device && {
      serial: device.serial_no,
      firmware: device.firmware_version,
      macAddress: device.mac_address,
      pairedAt: device.created_at,
    },
    noRecentSessions: sessionsDesc.length === 0,
    baseline: baselineAnalysis && {
      flexion: baselineAnalysis.joint_angle,
      range: baselineAnalysis.rom,
      recordedAt: baselineSession.performed_at,
    },
  });
};

const PatientUseCases = {
  async getAllPatients() {
    const [{ data: patientRows, error: patientsError }, allSessions] = await Promise.all([
      supabase
        .from("patients")
        .select(
          "*, patient_injuries(affected_side, affected_joint, injury_type, cause, diagnosis_date, first_injury, pain_level, description, created_at), wearable_devices(serial_no, firmware_version, mac_address, status, created_at)"
        )
        .order("created_at", { ascending: false }),
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

  // RLS silently matches zero rows when the physio isn't at the patient's
  // clinic, so `.select()` is used to tell "saved" apart from "not allowed".
  async approvePatient(id) {
    const { data, error } = await supabase.from("patients").update({ approved: true }).eq("id", id).select("id");
    if (error) throw new Error(error.message || "Unable to approve patient.");
    if (!data?.length) throw new Error("This patient is no longer in your clinic.");
  },

  // Saved on patients.warning, which the mobile app reads — so the patient
  // actually receives it, and it survives a refresh. Pass null to clear.
  async setWarning(id, message) {
    const { data, error } = await supabase
      .from("patients")
      .update({ warning: message })
      .eq("id", id)
      .select("id");
    if (error) throw new Error(error.message || "Unable to save the warning.");
    if (!data?.length) throw new Error("This patient is no longer in your clinic.");
  },

  // Deletes the patient record (injuries, sessions etc. cascade). The login
  // itself stays, so the patient is sent back through onboarding next time.
  async removePatient(id) {
    const { data, error } = await supabase.from("patients").delete().eq("id", id).select("id");
    if (error) throw new Error(error.message || "Unable to decline patient.");
    if (!data?.length) throw new Error("This patient is no longer in your clinic.");
  },
};

export default PatientUseCases;
