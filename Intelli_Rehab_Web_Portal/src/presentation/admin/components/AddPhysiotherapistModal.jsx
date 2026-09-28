import React, { useState } from "react";
import { X, Loader2, UserPlus, Eye, EyeOff } from "lucide-react";
import { passwordError } from "../../../infrastructure/validation/password";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const licensePattern = /^PMC-\d{5}$/i;
const namePattern = /^[A-Za-z.\s-]{3,}$/;
const physioIdPattern = /^(?=.{6,}$)(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d_-]+$/;
const cnicPattern = /^\d{5}-\d{7}-\d{1}$/;

export default function AddPhysiotherapistModal({ onClose, onSubmit }) {
  const [form, setForm] = useState({
    name: "",
    physioId: "",
    specialization: "",
    license: "",
    email: "",
    password: "",
    cnic: "",
    qualification: "",
    yearsExperience: "",
    joiningDate: "",
  });
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [hidePassword, setHidePassword] = useState(false);

  const validate = () => {
    const next = {};
    const name = form.name.trim();
    const physioId = form.physioId.trim();
    const email = form.email.trim();
    const specialization = form.specialization.trim();
    const license = form.license.trim();

    if (!name) next.name = "Full name is required.";
    else if (!namePattern.test(name)) next.name = "Enter a valid name with letters only.";

    if (!physioId) next.physioId = "Physiotherapist ID is required.";
    else if (!physioIdPattern.test(physioId)) next.physioId = "ID must be at least 8 characters and include letters and numbers.";

    if (!email) next.email = "Email is required.";
    else if (!emailPattern.test(email)) next.email = "Enter a valid email address.";

    const pwError = passwordError(form.password);
    if (pwError) next.password = pwError === "Password is required." ? "Set an initial password for them." : pwError;

    if (!specialization) next.specialization = "Specialization is required.";
    else if (specialization.length < 3) next.specialization = "Specialization must be at least 3 characters.";

    if (!license) next.license = "License number is required.";
    else if (!licensePattern.test(license)) next.license = "License must follow the format PMC-12345.";

    const cnic = form.cnic.trim();
    const qualification = form.qualification.trim();
    const yearsExperience = form.yearsExperience.trim();
    const joiningDate = form.joiningDate.trim();

    if (!cnic) next.cnic = "CNIC is required.";
    else if (!cnicPattern.test(cnic)) next.cnic = "CNIC must follow the format 12345-1234567-1.";

    if (!qualification) next.qualification = "Qualification is required.";
    else if (qualification.length < 2) next.qualification = "Enter a valid qualification, e.g. DPT.";

    if (!yearsExperience) next.yearsExperience = "Years of experience is required.";
    else if (!/^\d+$/.test(yearsExperience) || Number(yearsExperience) < 0 || Number(yearsExperience) > 60)
      next.yearsExperience = "Enter a whole number of years (0-60).";

    if (!joiningDate) next.joiningDate = "Joining date is required.";
    else if (new Date(joiningDate) > new Date()) next.joiningDate = "Joining date can't be in the future.";

    return next;
  };

  const submit = async (e) => {
    e.preventDefault();
    setErrorMessage("");
    const validation = validate();
    setErrors(validation);
    if (Object.keys(validation).length > 0) {
      setErrorMessage("Please fix the highlighted fields before adding.");
      return;
    }
    setSubmitting(true);
    try {
      await onSubmit(form);
    } catch (error) {
      setErrorMessage(error.message || "Unable to add physiotherapist.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(18,36,43,0.45)" }}
      role="dialog"
      aria-modal="true"
    >
      <div className="cp-root cp-card rounded-3xl w-full max-w-3xl p-6 sm:p-8 cp-fade-in overflow-y-auto max-h-[90dvh]">
        <div className="flex items-start justify-between gap-3 mb-6">
          <div className="min-w-0">
            <p className="text-[12px] font-semibold uppercase tracking-[0.18em] text-[var(--muted)] mb-1">Add physiotherapist</p>
            <h3 className="cp-display font-bold text-[20px] sm:text-[22px]">Invite a new physiotherapist to the clinic</h3>
          </div>
          <button
            onClick={onClose}
            className="cp-focus text-[var(--muted)] hover:text-[var(--ink)] rounded-full p-2 -mr-2 -mt-1 flex-shrink-0"
            aria-label="Close add physiotherapist modal"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="block text-[13px] font-semibold mb-1.5">Full name</label>
            <input
              value={form.name}
              onChange={(e) => {
                setForm({ ...form, name: e.target.value });
                if (errors.name) setErrors({ ...errors, name: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              placeholder="Dr. Full Name"
            />
            {errors.name && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.name}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Physiotherapist ID</label>
            <input
              value={form.physioId}
              onChange={(e) => {
                setForm({ ...form, physioId: e.target.value });
                if (errors.physioId) setErrors({ ...errors, physioId: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px] cp-mono"
              placeholder="e.g., DRID2025"
            />
            {errors.physioId && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.physioId}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Email</label>
            <input
              value={form.email}
              onChange={(e) => {
                setForm({ ...form, email: e.target.value });
                if (errors.email) setErrors({ ...errors, email: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              placeholder="name@yourclinic.pk"
              type="email"
            />
            {errors.email && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.email}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Initial password</label>
            <div className="relative">
              <input
                value={form.password}
                onChange={(e) => {
                  setForm({ ...form, password: e.target.value });
                  if (errors.password) setErrors({ ...errors, password: undefined });
                }}
                className="cp-input cp-focus w-full rounded-2xl px-4 pr-10 py-3 text-[14px] cp-mono"
                placeholder="At least 8 characters"
                type={hidePassword ? "password" : "text"}
              />
              <button
                type="button"
                onClick={() => setHidePassword((v) => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--muted)] bg-transparent border-none cursor-pointer p-0 flex"
                aria-label={hidePassword ? "Show password" : "Hide password"}
              >
                {hidePassword ? <Eye size={16} /> : <EyeOff size={16} />}
              </button>
            </div>
            {errors.password && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.password}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Specialization</label>
            <input
              value={form.specialization}
              onChange={(e) => {
                setForm({ ...form, specialization: e.target.value });
                if (errors.specialization) setErrors({ ...errors, specialization: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              placeholder="e.g., Orthopedic Rehab"
            />
            {errors.specialization && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.specialization}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">License number</label>
            <input
              value={form.license}
              onChange={(e) => {
                setForm({ ...form, license: e.target.value });
                if (errors.license) setErrors({ ...errors, license: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px] cp-mono"
              placeholder="PMC-XXXXX"
            />
            {errors.license && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.license}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">CNIC</label>
            <input
              value={form.cnic}
              onChange={(e) => {
                setForm({ ...form, cnic: e.target.value });
                if (errors.cnic) setErrors({ ...errors, cnic: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px] cp-mono"
              placeholder="12345-1234567-1"
            />
            {errors.cnic && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.cnic}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Qualification</label>
            <input
              value={form.qualification}
              onChange={(e) => {
                setForm({ ...form, qualification: e.target.value });
                if (errors.qualification) setErrors({ ...errors, qualification: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              placeholder="e.g., DPT (Doctor of Physical Therapy)"
            />
            {errors.qualification && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.qualification}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Years of experience</label>
            <input
              value={form.yearsExperience}
              onChange={(e) => {
                setForm({ ...form, yearsExperience: e.target.value });
                if (errors.yearsExperience) setErrors({ ...errors, yearsExperience: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              placeholder="e.g., 3"
              type="number"
              min="0"
              max="60"
            />
            {errors.yearsExperience && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.yearsExperience}</div>}
          </div>

          <div>
            <label className="block text-[13px] font-semibold mb-1.5">Joining date</label>
            <input
              value={form.joiningDate}
              onChange={(e) => {
                setForm({ ...form, joiningDate: e.target.value });
                if (errors.joiningDate) setErrors({ ...errors, joiningDate: undefined });
              }}
              className="cp-input cp-focus w-full rounded-2xl px-4 py-3 text-[14px]"
              type="date"
            />
            {errors.joiningDate && <div className="text-[13px] text-[var(--alert)] mt-2">{errors.joiningDate}</div>}
          </div>

          <div className="sm:col-span-2">
            <div className="rounded-2xl bg-[var(--primary-tint)] border border-[var(--border)] px-4 py-3 text-[13px] text-[var(--ink)] mb-2">
              Share this password with them directly — they can change it after logging in. They're added
              with <strong>Pending</strong> status and still can't log in until you verify their credentials
              and approve them from the roster.
            </div>
          </div>

          <div className="sm:col-span-2">
            {errorMessage ? (
              <div className="rounded-2xl bg-[rgba(217,98,72,0.1)] border border-[rgba(217,98,72,0.2)] px-4 py-3 text-[13px] text-[var(--alert)] mb-4">
                {errorMessage}
              </div>
            ) : null}
            <button
              type="submit"
              disabled={submitting}
              className="cp-btn-primary cp-focus w-full rounded-2xl py-3 text-[14px] flex items-center justify-center gap-2 mt-2 disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {submitting ? (
                <>
                  <Loader2 size={16} className="animate-spin" /> Adding...
                </>
              ) : (
                <>
                  <UserPlus size={15} /> Add to clinic
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
