import React, { useState, useEffect } from "react";
import { Building2, MapPin, Phone, Mail, Loader2, Save, Check } from "lucide-react";
import SectionHeading from "../components/SectionHeading";
import useClinicProfile from "../../../domain/admin/useClinicProfile";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phonePattern = /^\+?\d{10,15}$/;

export default function ClinicProfilePanel({ clinic, onClinicUpdated }) {
  const { profile, saving, save } = useClinicProfile(clinic);
  const [form, setForm] = useState(clinic);
  const [saved, setSaved] = useState(false);
  const [errors, setErrors] = useState({});
  const [saveError, setSaveError] = useState("");

  useEffect(() => {
    if (profile) setForm(profile);
  }, [profile]);

  const validate = () => {
    const next = {};
    const name = (form?.name || "").trim();
    const address = (form?.address || "").trim();
    const phone = (form?.phone || "").trim();
    const email = (form?.email || "").trim();

    if (!name) next.name = "Clinic name is required.";
    else if (name.length < 3) next.name = "Clinic name must have at least 3 characters.";

    if (!address) next.address = "Address is required.";
    else if (address.length < 6) next.address = "Enter a more complete address.";

    if (!phone) next.phone = "Contact number is required.";
    else if (!phonePattern.test(phone)) next.phone = "Enter a valid phone number with 10–15 digits.";

    if (!email) next.email = "Contact email is required.";
    else if (!emailPattern.test(email)) next.email = "Enter a valid email address.";

    return next;
  };

  const submit = async (e) => {
    e.preventDefault();
    const validation = validate();
    setErrors(validation);
    if (Object.keys(validation).length > 0) return;
    setSaveError("");
    try {
      const updated = await save(form);
      onClinicUpdated?.(updated); // keep the header / shell in sync
      setSaved(true);
      setTimeout(() => setSaved(false), 2200);
    } catch (err) {
      setSaveError(err.message || "Unable to save clinic profile.");
    }
  };

  const fields = [
    { key: "name", label: "Clinic name", icon: Building2 },
    { key: "address", label: "Address", icon: MapPin },
    { key: "phone", label: "Contact number", icon: Phone },
    { key: "email", label: "Contact email", icon: Mail },
  ];

  if (!form) return null;

  return (
    <div>
      <SectionHeading eyebrow="SETTINGS" title="Clinic profile" />
      <form onSubmit={submit} className="cp-card rounded-2xl p-6 max-w-lg space-y-4 text-[var(--ink)]">
        {fields.map((f) => {
          const Icon = f.icon;
          return (
            <div key={f.key}>
              <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">{f.label}</label>
              <div className="relative">
                <Icon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
                <input
                  value={form[f.key] || ""}
                  onChange={(e) => {
                    setForm({ ...form, [f.key]: e.target.value });
                    if (errors[f.key]) setErrors({ ...errors, [f.key]: undefined });
                  }}
                  className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px]"
                  style={errors[f.key] ? { borderColor: "var(--alert)" } : undefined}
                />
              </div>
              {errors[f.key] && <div className="text-[13px] text-[var(--alert)] mt-2">{errors[f.key]}</div>}
            </div>
          );
        })}
        {saveError && (
          <div className="text-[13px] text-[var(--alert)]">{saveError}</div>
        )}
        <div className="flex items-center gap-3 pt-2">
          <button
            type="submit"
            disabled={saving}
            className="cp-btn-primary cp-focus rounded-lg px-5 py-2.5 text-[13.5px] flex items-center gap-1.5 cursor-pointer"
          >
            {saving ? (
              <>
                <Loader2 size={15} className="animate-spin" /> Saving…
              </>
            ) : (
              <>
                <Save size={14} /> Save changes
              </>
            )}
          </button>
          {saved && (
            <span className="text-[var(--success)] text-[13px] font-semibold flex items-center gap-1 cp-fade-in">
              <Check size={14} /> Saved
            </span>
          )}
        </div>
      </form>
    </div>
  );
}
