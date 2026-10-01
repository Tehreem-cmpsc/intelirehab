import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

// Maps a real `physiotherapists` row (+ the name we store on it) to the shape
// the admin UI expects.
const toUiShape = (row) => ({
  id: row.id,
  name: row.full_name || row.physio_code,
  specialization: row.specialization,
  license: row.license_number,
  status: row.status,
  physioId: row.physio_code,
  cnic: row.cnic,
  qualification: row.qualification,
  yearsExperience: row.years_experience,
  joiningDate: row.joining_date,
});

export default function usePhysiotherapists(clinicId) {
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
    const { data, error } = await supabase
      .from("physiotherapists")
      .select("*")
      .eq("clinic_id", clinicId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Failed to load physiotherapists:", error);
      setError("Unable to load this data. Check your connection and try again.");
      setList([]);
    } else {
      setList((data ?? []).map(toUiShape));
    }
    setLoading(false);
  }, [clinicId]);

  useEffect(() => { refresh(); }, [refresh]);

  // Edge Function errors arrive as a generic FunctionsHttpError; the useful
  // message is in the response body.
  const functionError = async (error, fallback) => {
    try {
      const body = await error.context.json();
      if (body?.error) return new Error(body.error);
    } catch {
      // not JSON - use the fallback
    }
    return new Error(fallback);
  };

  // Account + profile are created together server-side (manage-physiotherapist):
  // the password is generated there and returned once, the clinic is taken
  // from the caller's identity, and a failure leaves nothing half-created.
  const addPhysiotherapist = useCallback(async (form) => {
    if (!clinicId) throw new Error("No clinic is associated with this admin account.");

    const { data, error } = await supabase.functions.invoke("manage-physiotherapist", {
      body: {
        action: "create",
        name: form.name.trim(),
        email: form.email.trim(),
        physioId: form.physioId.trim(),
        specialization: form.specialization.trim(),
        license: form.license.trim(),
        cnic: form.cnic.trim(),
        qualification: form.qualification.trim(),
        yearsExperience: Number(form.yearsExperience),
        joiningDate: form.joiningDate,
      },
    });
    if (error) throw await functionError(error, "Unable to add the physiotherapist.");

    const record = { ...toUiShape(data.physio), temporaryPassword: data.temporaryPassword };
    setList((cur) => [record, ...cur]);
    return record;
  }, [clinicId]);

  const removePhysiotherapist = useCallback(async (id) => {
    const { error } = await supabase.functions.invoke("manage-physiotherapist", {
      body: { action: "remove", id },
    });
    if (error) throw await functionError(error, "Unable to remove physiotherapist.");
    setList((cur) => cur.filter((item) => item.id !== id));
  }, []);

  const approvePhysiotherapist = useCallback(async (id) => {
    const { data, error } = await supabase
      .from("physiotherapists")
      .update({ status: "Active" })
      .eq("id", id)
      .select()
      .single();
    if (error) throw new Error(error.message || "Unable to approve physiotherapist.");
    const record = toUiShape(data);
    setList((cur) => cur.map((item) => (item.id === id ? record : item)));

    try {
      await supabase.from("activity_log").insert({
        clinic_id: clinicId,
        message: `${record.name} was approved and can now log in.`,
      });
    } catch (err) {
      console.error("Failed to record activity log entry:", err);
    }

    return record;
  }, [clinicId]);

  return { list, loading, error, addPhysiotherapist, removePhysiotherapist, approvePhysiotherapist, refresh };
}
