// PORTAL_ORIGIN may hold several comma-separated origins (production, staging).
// The local dev server is always allowed so `npm run dev` works against a
// deployed function.
const configured = (Deno.env.get("PORTAL_ORIGIN") ?? "")
  .split(",")
  .map((s) => s.trim().replace(/\/$/, ""))
  .filter(Boolean);
const DEV_ORIGINS = ["http://localhost:5173", "http://127.0.0.1:5173"];

export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  const allowed = configured.length === 0 || configured.includes(origin) || DEV_ORIGINS.includes(origin);
  return {
    "Access-Control-Allow-Origin": allowed ? origin || "*" : configured[0] ?? "",
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

export function json(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
