import React from "react";

// Last line of defence: an unexpected render error shows a recoverable
// message instead of a blank white page.
export default class ErrorBoundary extends React.Component {
  state = { error: null };

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error("Unhandled UI error:", error, info?.componentStack);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div
        role="alert"
        style={{
          minHeight: "100dvh",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 12,
          padding: 24,
          textAlign: "center",
          fontFamily: "system-ui, sans-serif",
        }}
      >
        <h1 style={{ fontSize: 20, margin: 0 }}>Something went wrong</h1>
        <p style={{ maxWidth: 420, margin: 0, opacity: 0.75 }}>
          The page hit an unexpected error. Your data is safe — reload to continue.
        </p>
        <button
          onClick={() => window.location.reload()}
          style={{ padding: "10px 20px", borderRadius: 10, border: 0, background: "#0d9488", color: "#fff", fontWeight: 600, cursor: "pointer" }}
        >
          Reload
        </button>
      </div>
    );
  }
}
