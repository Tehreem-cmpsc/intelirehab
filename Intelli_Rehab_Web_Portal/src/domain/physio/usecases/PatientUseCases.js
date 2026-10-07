import { supabase } from "../../../infrastructure/supabase/supabaseClient";
import { Patient } from "../entities";
import SessionUseCases from "./SessionUseCases";
import { formatSessionForUi, computeStreak, computeWeeklyRom } from "../utils/sessionAnalytics";
import { assessRiskDetailed, riskSeverity } from "../utils/riskAssessment";

const REALTIME_DEBOUNCE_MS = 1500;

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
const toPatient = (row, sessionsForPatient, riskSettings) => {
  const exerciseSessions = sessionsForPatient.filter((s) => !isBaseline(s));
  const sessionsDesc = exerciseSessions
    .map(formatSessionForUi)
    .sort((a, b) => b.performedAt - a.performedAt);
  const sessionsAsc = [...sessionsDesc].reverse();

  // Nothing writes status = 'at-risk', so it is worked out from the sessions here. A status
  // someone set by hand ('recovered', or 'at-risk') is kept.
  // Sessions before the physio's last warning have been dealt with (risk_reviewed_at), so they no longer count.
  const risk = assessRiskDetailed(
    [...exerciseSessions].sort((a, b) => new Date(b.performed_at) - new Date(a.performed_at)),
    new Date(),
    row.risk_reviewed_at,
    riskSettings
  );
  const riskReasons = risk.map((r) => r.text);
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
    riskSeverity: riskSeverity(risk),
    warningSentAt: row.warning_sent_at ?? null,
    // wearable_connected is kept in sync by a trigger
    // (supabase_patient_wearable_sync.sql); the device row is checked too
    // in case that trigger isn't installed.
    wearable: Boolean(row.wearable_connected || device),
    approved: row.approved,
    warning: row.warning,
    safetyLimits: {
      maxAngleDeg: row.safety_max_angle_deg ?? null,
      maxSpeedDegPerSec: row.safety_max_speed_deg_s ?? null,
    },
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
  // `riskSettings`: the clinic's own at-risk thresholds (clinics.risk_settings); null = the defaults.
  async getAllPatients(riskSettings = null) {
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

    return (patientRows ?? []).map((row) => toPatient(row, sessionsByPatient.get(row.id) ?? [], riskSettings));
  },

  // Calls onChange (debounced) whenever a session or a patient row changes - a patient finishing a
  // session, a new sign-up, a warning sent or erased - so the lists update without waiting for the
  // 60 s refresh. If realtime isn't enabled for these tables nothing fires and the refresh still runs.
  // Returns an unsubscribe function.
  subscribe(onChange) {
    let timer = null;
    const fire = () => {
      clearTimeout(timer);
      timer = setTimeout(onChange, REALTIME_DEBOUNCE_MS);
    };
    const channel = supabase
      .channel("physio-patients")
      .on("postgres_changes", { event: "*", schema: "public", table: "sessions" }, fire)
      .on("postgres_changes", { event: "*", schema: "public", table: "patients" }, fire)
      .subscribe();
    return () => {
      clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  },

  // Whether each patient has seen the warning currently on their record: Map of patientId -> Date | null
  // (when they tapped "Got it"). Empty when the log doesn't exist yet.
  async getOpenWarningReceipts() {
    const { data, error } = await supabase
      .from("patient_warning_log")
      .select("patient_id, read_at")
      .is("cleared_at", null);
    if (error) {
      if (error.code === "42P01" || error.code === "PGRST205" || error.code === "42703") return new Map();
      console.error("Error loading warning receipts:", error);
      throw error;
    }
    return new Map((data ?? []).map((r) => [r.patient_id, r.read_at ? new Date(r.read_at) : null]));
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

  // The red "stop" limits the patient's app uses (supabase_session_module_v2.sql). null clears one back
  // to the app's built-in default. The database enforces the allowed ranges; this checks first so the
  // physio gets a plain message instead of a constraint name.
  async setSafetyLimits(id, { maxAngleDeg, maxSpeedDegPerSec }) {
    const angle = maxAngleDeg === "" || maxAngleDeg == null ? null : Number(maxAngleDeg);
    const speed = maxSpeedDegPerSec === "" || maxSpeedDegPerSec == null ? null : Number(maxSpeedDegPerSec);
    if (angle !== null && (!Number.isInteger(angle) || angle < 60 || angle > 180)) {
      throw new Error("The angle limit must be a whole number from 60 to 180 degrees.");
    }
    if (speed !== null && (!Number.isInteger(speed) || speed < 60 || speed > 1000)) {
      throw new Error("The speed limit must be a whole number from 60 to 1000 degrees per second.");
    }
    const { data, error } = await supabase
      .from("patients")
      .update({ safety_max_angle_deg: angle, safety_max_speed_deg_s: speed })
      .eq("id", id)
      .select("id");
    if (error) {
      if (error.code === "42703" || error.code === "PGRST204") {
        throw new Error("Safety limits need the latest database update (supabase_session_module_v2.sql).");
      }
      throw new Error(error.message || "Unable to save the safety limits.");
    }
    if (!data?.length) throw new Error("This patient is no longer in your clinic.");
    return { maxAngleDeg: angle, maxSpeedDegPerSec: speed };
  },

  // Past warnings and what ended them (supabase_warning_autoclear.sql), newest first. Empty when the
  // log doesn't exist yet.
  async getWarningHistory(patientId, limit = 5) {
    const { data, error } = await supabase
      .from("patient_warning_log")
      .select("id, message, sent_at, read_at, cleared_at, cleared_by, cleared_session_id, sessions:cleared_session_id(performed_at, exercises(name))")
      .eq("patient_id", patientId)
      .order("sent_at", { ascending: false })
      .limit(limit);
    if (error) {
      if (error.code === "42P01" || error.code === "PGRST205" || error.code === "PGRST200") return [];
      console.error("Error loading warning history:", error);
      throw error;
    }
    return (data ?? []).map((w) => ({
      id: w.id,
      message: w.message,
      sentAt: new Date(w.sent_at),
      readAt: w.read_at ? new Date(w.read_at) : null, // when the patient tapped "Got it"
      clearedAt: w.cleared_at ? new Date(w.cleared_at) : null,
      clearedBy: w.cleared_by, // 'session' | 'physio' | 'replaced'
      clearedSession: w.sessions
        ? { performedAt: new Date(w.sessions.performed_at), exercise: w.sessions.exercises?.name ?? null }
        : null,
    }));
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
