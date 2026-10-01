import { useMemo, useSyncExternalStore } from "react";

// Minimal hash router (#/app/patients/<id>) — gives the portal real URLs,
// working Back/Forward and refresh-in-place without a router dependency or
// any server-side rewrite rules. Anything that isn't "#/..." (including
// Supabase's own "#access_token=…" auth redirects) reads as the landing page.

const subscribe = (cb) => {
  window.addEventListener("hashchange", cb);
  return () => window.removeEventListener("hashchange", cb);
};
const getHash = () => window.location.hash;

export function parseHash(hash) {
  if (!hash.startsWith("#/")) return [];
  return hash
    .slice(2)
    .split("/")
    .filter(Boolean)
    .map((s) => {
      try {
        return decodeURIComponent(s);
      } catch {
        return s;
      }
    });
}

export function navigate(path, { replace = false } = {}) {
  const target = `#${path}`;
  if (window.location.hash === target) return;
  if (replace) {
    // replaceState doesn't fire hashchange, so subscribers are told by hand.
    window.history.replaceState(null, "", target);
    window.dispatchEvent(new HashChangeEvent("hashchange"));
  } else {
    window.location.hash = path;
  }
}

export default function useHashRoute() {
  const hash = useSyncExternalStore(subscribe, getHash, () => "");
  return useMemo(() => parseHash(hash), [hash]);
}
