import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

export default function useClinicProfile(initial) {
  const [profile, setProfile] = useState(initial);
  const [saving, setSaving] = useState(false);
  useEffect(() => { if (initial) setProfile(initial); }, [initial]);

  const save = useCallback(async (next) => {
    if (!next?.id) throw new Error("No clinic is associated with this admin account.");
    setSaving(true);
    try {
      const { data, error } = await supabase
        .from("clinics")
        .update({
          name: next.name,
          address: next.address,
          phone: next.phone,
          email: next.email,
        })
        .eq("id", next.id)
        .select()
        .single();

      if (error) throw new Error(error.message || "Unable to save clinic profile.");
      setProfile(data);
      return data;
    } finally {
      setSaving(false);
    }
  }, []);

  return { profile, saving, save };
}
