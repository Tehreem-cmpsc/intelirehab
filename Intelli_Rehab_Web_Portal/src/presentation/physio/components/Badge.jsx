import { STATUS_META } from "../../../infrastructure/physio/constants";

function Badge({ status }) {
  const m = STATUS_META[status] || STATUS_META.active;
  return (
    <span
      style={{
        background: m.bg,
        color: m.c,
        borderRadius: 20,
        padding: "3px 10px",
        fontSize: 11,
        fontWeight: 600,
      }}
    >
      {m.label}
    </span>
  );
}

export default Badge;
