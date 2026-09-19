import { THEME } from "../../../infrastructure/physio/constants";

function SectionHead({ title, sub, action }) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "flex-start",
        marginBottom: 28,
      }}
    >
      <div>
        <div style={{ fontSize: 28, fontWeight: 800, color: THEME.slate800 }}>
          {title}
        </div>
        <div style={{ fontSize: 14, color: THEME.slate400, marginTop: 4 }}>
          {sub}
        </div>
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}

export default SectionHead;
