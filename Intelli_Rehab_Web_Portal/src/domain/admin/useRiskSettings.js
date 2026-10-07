import { useState, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";
import { RISK_SETTING_FIELDS, normalizeRiskSettings } from "../physio/utils/riskAssessment";

// Reads and saves the clinic's own at-risk thresholds (clinics.risk_settings). Saving checks every value
// first, so the administrator gets a plain message instead of the portal quietly ignoring a bad one.
export default function useRiskSettings(clinic) {
  const [saving, setSaving] = useState(false);
  const settings = normalizeRiskSettings(clinic?.risk_settings);

  const validate = useCallback((draft) => {
    const errors = {};
    for (const { key, label, min, max } of RISK_SETTING_FIELDS) {
      const v = Number(draft[key]);
      if (draft[key] === "" || !Number.isInteger(v) || v < min || v > max) {
        errors[key] = `${label}: enter a whole number from ${min} to ${max}.`;
      }
    }
    return errors;
  }, []);

  // Returns the saved clinic row (with risk_settings), or throws a readable error.
  const save = useCallback(
    async (draft) => {
      if (!clinic?.id) throw new Error("No clinic is associated with this admin account.");
      const errors = validate(draft);
      if (Object.keys(errors).length) throw new Error(Object.values(errors)[0]);
      const next = normalizeRiskSettings(draft);
      setSaving(true);
      try {
        const { data, error } = await supabase
          .from("clinics")
          .update({ risk_settings: next })
          .eq("id", clinic.id)
          .select()
          .single();
        if (error) {
          if (error.code === "42703" || error.code === "PGRST204") {
            throw new Error("At-risk rules need the latest database update (supabase_session_module_v2.sql).");
          }
          throw new Error(error.message || "Unable to save the at-risk rules.");
        }
        return data;
      } finally {
        setSaving(false);
      }
    },
    [clinic?.id, validate]
  );

  return { settings, saving, save, validate };
}
