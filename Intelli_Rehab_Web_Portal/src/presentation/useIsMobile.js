import { useEffect, useState } from "react";

// Below this width the portal switches to its mobile layout: sidebars
// become slide-in drawers and wide tables become stacked cards.
export const MOBILE_BREAKPOINT = 900;

const query = `(max-width: ${MOBILE_BREAKPOINT - 1}px)`;

export default function useIsMobile() {
  const [isMobile, setIsMobile] = useState(
    () => typeof window !== "undefined" && window.matchMedia(query).matches
  );

  useEffect(() => {
    const mql = window.matchMedia(query);
    const onChange = (e) => setIsMobile(e.matches);
    setIsMobile(mql.matches);
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, []);

  return isMobile;
}
