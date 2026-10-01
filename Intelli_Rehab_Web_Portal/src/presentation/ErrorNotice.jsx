// Inline, user-visible load/save failure with an optional retry — replaces
// errors that used to be console-only.
export default function ErrorNotice({ message, onRetry }) {
  if (!message) return null;
  return (
    <div
      role="alert"
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: "10px 14px",
        marginBottom: 16,
        borderRadius: 10,
        border: "1px solid var(--alert, #dc2626)",
        background: "color-mix(in srgb, var(--alert, #dc2626) 10%, transparent)",
        color: "var(--alert, #dc2626)",
        fontSize: 13.5,
        fontWeight: 600,
      }}
    >
      <span style={{ flex: 1 }}>{message}</span>
      {onRetry && (
        <button
          onClick={onRetry}
          style={{ border: 0, background: "transparent", color: "inherit", fontWeight: 700, textDecoration: "underline", cursor: "pointer" }}
        >
          Retry
        </button>
      )}
    </div>
  );
}
