import { useCallback, useEffect, useRef, useState } from "react";

// One toast for every screen. Showing a new one replaces the old and
// restarts the timer (so quick successive actions don't cut each other
// short), and the timer is cleared on unmount.
export default function useToast() {
  const [toast, setToast] = useState(null);
  const timer = useRef(null);

  useEffect(() => () => clearTimeout(timer.current), []);

  const showToast = useCallback((message, { error = false } = {}) => {
    clearTimeout(timer.current);
    setToast({ message, error });
    timer.current = setTimeout(() => setToast(null), error ? 5000 : 3000);
  }, []);

  const toastNode = toast && (
    <div
      role={toast.error ? "alert" : "status"}
      style={{
        position: "fixed",
        top: 16,
        right: 16,
        left: "auto",
        maxWidth: "calc(100vw - 32px)",
        background: toast.error ? "#c0392b" : "#093D42",
        color: "#fff",
        borderRadius: 10,
        padding: "12px 20px",
        zIndex: 300,
        fontSize: 14,
        fontWeight: 600,
        boxShadow: "0 8px 24px rgba(0,0,0,0.2)",
      }}
    >
      {toast.error ? "! " : "✓ "}
      {toast.message}
    </div>
  );

  return { toastNode, showToast };
}
