import { THEME } from "../../../infrastructure/physio/constants";

function Card({ children, style = {} }) {
  const isDark = typeof document !== "undefined" && document.documentElement.getAttribute("data-theme") === "dark";

  return (
    <div
      style={{
        background: isDark ? THEME.slate100 : THEME.white,
        borderRadius: 14,
        border: `1px solid ${THEME.slate200}`,
        boxShadow: isDark ? "0 1px 4px rgba(0,0,0,0.2)" : "0 1px 4px rgba(0,0,0,0.05)",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

export default Card;
