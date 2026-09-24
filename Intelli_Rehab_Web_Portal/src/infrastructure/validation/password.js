// A password strength floor, not full NIST-style complexity — shared so a
// physio setting their own password (SetPasswordPage) and an admin setting
// one for them (AddPhysiotherapistModal) are held to the same bar, rather
// than two components silently drifting out of sync.
export function passwordError(password) {
  if (!password) return "Password is required.";
  if (password.length < 8) return "Use at least 8 characters.";
  if (!/[a-zA-Z]/.test(password)) return "Include at least one letter.";
  if (!/[0-9]/.test(password)) return "Include at least one number.";
  return null;
}
