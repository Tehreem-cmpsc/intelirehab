import { useCallback, useEffect, useRef, useState } from "react";

// Promise-based replacement for window.confirm:
//   const { confirm, confirmNode } = useConfirm();
//   if (!(await confirm({ title, message, confirmLabel, destructive }))) return;
// Render {confirmNode} once in the component.
export default function useConfirm() {
  const [options, setOptions] = useState(null);
  const resolver = useRef(null);

  const settle = useCallback((value) => {
    resolver.current?.(value);
    resolver.current = null;
    setOptions(null);
  }, []);

  const confirm = useCallback(
    (opts) =>
      new Promise((resolve) => {
        resolver.current?.(false);
        resolver.current = resolve;
        setOptions(opts);
      }),
    []
  );

  useEffect(() => {
    if (!options) return;
    const onKey = (e) => {
      if (e.key === "Escape") settle(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [options, settle]);

  // Unmounting while open resolves as "no" rather than leaving a hung promise.
  useEffect(() => () => resolver.current?.(false), []);

  const confirmNode = options && (
    <div
      onClick={() => settle(false)}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(4, 20, 23, 0.55)",
        zIndex: 400,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 16,
      }}
    >
      <div
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="confirm-title"
        onClick={(e) => e.stopPropagation()}
        style={{
          background: "var(--surface, #fff)",
          color: "var(--ink, #0b2a30)",
          borderRadius: 16,
          padding: 24,
          width: "100%",
          maxWidth: 400,
          boxShadow: "0 20px 50px rgba(0,0,0,0.3)",
        }}
      >
        <h2 id="confirm-title" style={{ margin: "0 0 8px", fontSize: 17, fontWeight: 700 }}>
          {options.title}
        </h2>
        <p style={{ margin: "0 0 20px", fontSize: 14, lineHeight: 1.5, opacity: 0.8 }}>{options.message}</p>
        <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
          <button
            autoFocus
            onClick={() => settle(false)}
            style={{ padding: "9px 18px", borderRadius: 9, border: "1px solid var(--border, #cbd5e1)", background: "transparent", color: "inherit", fontWeight: 600, cursor: "pointer" }}
          >
            {options.cancelLabel ?? "Cancel"}
          </button>
          <button
            onClick={() => settle(true)}
            style={{
              padding: "9px 18px",
              borderRadius: 9,
              border: 0,
              background: options.destructive ? "#c0392b" : "#0d9488",
              color: "#fff",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            {options.confirmLabel ?? "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );

  return { confirm, confirmNode };
}
