import { Sun, Moon } from "lucide-react";

// Shared toggle button for pages outside the admin/physio shells (which
// already have their own inline version in their header). Uses the same
// --ink/--border/--surface tokens those shells inject, so it stays
// legible in both themes without needing its own dark-mode branching.
export default function ThemeToggle({ dark, setDark, style }) {
  return (
    <button
      onClick={() => setDark((v) => !v)}
      title={dark ? "Switch to light mode" : "Switch to dark mode"}
      aria-label={dark ? "Switch to light mode" : "Switch to dark mode"}
      className="cp-focus"
      style={{
        width: 38,
        height: 38,
        borderRadius: 12,
        border: `1px solid var(--border)`,
        background: "var(--surface)",
        color: "var(--ink)",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        cursor: "pointer",
        flexShrink: 0,
        ...style,
      }}
    >
      {dark ? <Sun size={17} /> : <Moon size={17} />}
    </button>
  );
}
