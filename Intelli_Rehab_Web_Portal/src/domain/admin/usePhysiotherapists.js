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

  const refresh = useCallback(async () => {
    if (!clinicId) {
      setList([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from("physiotherapists")
      .select("*")
      .eq("clinic_id", clinicId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Failed to load physiotherapists:", error);
      setList([]);
    } else {
      setList((data ?? []).map(toUiShape));
    }
    setLoading(false);
  }, [clinicId]);

  useEffect(() => { refresh(); }, [refresh]);

  const addPhysiotherapist = useCallback(async (form) => {
    if (!clinicId) throw new Error("No clinic is associated with this admin account.");

    const email = form.email.trim();
    const name = form.name.trim();
    const physioCode = form.physioId.trim();

    // Creating another user from the browser (no service-role key available
    // here) briefly swaps the active session to the new user, so we snapshot
    // the admin's session first and restore it once the account exists.
    const { data: { session: adminSession } } = await supabase.auth.getSession();

    // The admin sets the physio's initial password directly and hands it to
    // them outside the app — Supabase's default email sender is rate-limited
    // and unreliable for real delivery, and no custom SMTP is configured yet.
    // The physio can change it after logging in for the first time.
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
      email,
      password: form.password,
      options: { data: { full_name: name } },
    });

    if (adminSession) {
      await supabase.auth.setSession({
        access_token: adminSession.access_token,
        refresh_token: adminSession.refresh_token,
      });
    }

    if (signUpError) {
      throw new Error(signUpError.message || "Unable to create the physiotherapist's account.");
    }
    // Supabase returns a user with no identities (and no error) when the
    // email is already registered, to avoid leaking which emails exist.
    if (signUpData.user && signUpData.user.identities?.length === 0) {
      throw new Error("An account with this email already exists.");
    }

    const newUserId = signUpData.user?.id;
    if (!newUserId) {
      throw new Error("Unable to create the physiotherapist's account.");
    }

    const { data: inserted, error: insertError } = await supabase
      .from("physiotherapists")
      .insert({
        user_id: newUserId,
        physio_code: physioCode,
        full_name: name,
        specialization: form.specialization.trim(),
        license_number: form.license.trim(),
        cnic: form.cnic.trim(),
        qualification: form.qualification.trim(),
        years_experience: Number(form.yearsExperience),
        joining_date: form.joiningDate,
        // New physios start Pending — an admin must verify their
        // credentials and approve them before they can log in.
        status: "Pending",
        clinic_id: clinicId,
      })
      .select()
      .single();

    if (insertError) {
      // The auth account exists at this point but the profile row didn't get
      // created — surface that clearly since it needs manual cleanup.
      throw new Error(
        `Account was created but saving the profile failed: ${insertError.message}. ` +
        "Contact support before reusing this physiotherapist ID or email."
      );
    }

    // Best-effort — the physio account is already created either way, so a
    // failed log entry shouldn't surface as an error to the admin.
    try {
      await supabase.from("activity_log").insert({
        clinic_id: clinicId,
        message: `${name} was added to the roster and is awaiting approval.`,
      });
    } catch (err) {
      console.error("Failed to record activity log entry:", err);
    }

    const record = toUiShape(inserted);
    setList((cur) => [record, ...cur]);
    return record;
  }, [clinicId]);

  const removePhysiotherapist = useCallback(async (id) => {
    const { error } = await supabase.from("physiotherapists").delete().eq("id", id);
    if (error) throw new Error(error.message || "Unable to remove physiotherapist.");
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

  return { list, loading, addPhysiotherapist, removePhysiotherapist, approvePhysiotherapist, refresh };
}
