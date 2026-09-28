import Logo from "./Logo";
import { THEME } from "../../../infrastructure/physio/constants";

function LogoFull({ dark = false }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <Logo size={32} dark={dark} />
      <div
        style={{
          fontSize: 16,
          fontWeight: 800,
          color: dark ? THEME.white : THEME.navy,
          lineHeight: 1,
        }}
      >
        Inteli
        {/* On the dark sidebar the deep teal disappears; use the bright one. */}
        <span style={{ color: dark ? THEME.tealBright : THEME.teal }}>Rehab</span>
      </div>
    </div>
  );
}

export default LogoFull;
