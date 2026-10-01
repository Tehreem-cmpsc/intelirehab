// Physiotherapist ID -> login, done server-side so the browser can never
// look up an email from an ID, and failures don't reveal whether an ID
// exists (same generic answer for unknown ID and wrong password).
//
//   sign-in: { action, physioCode, password } -> { session } or 401
//   reset:   { action, physioCode }           -> always { ok: true }
//
// Deploy with JWT verification off (callers aren't signed in yet):
//   supabase functions deploy physio-auth --no-verify-jwt
// Set PORTAL_URL (password-reset redirect) and PORTAL_ORIGIN (CORS):
//   supabase secrets set PORTAL_URL=https://portal.example.com PORTAL_ORIGIN=https://portal.example.com
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeadersFor, json } from "../_shared/cors.ts";

const GENERIC = "Invalid ID or password.";
const MAX_ATTEMPTS = 8; // per physio ID...
const WINDOW_MS = 15 * 60 * 1000; // ...per 15 minutes

Deno.serve(async (req) => {
  const cors = corsHeadersFor(req);
  const respond = (body: unknown, status = 200) => json(body, status, cors);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond({ error: "Method not allowed." }, 405);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid request." }, 400);
  }
  const physioCode = String(body.physioCode ?? "").trim();
  if (!physioCode || physioCode.length > 64) return respond({ error: GENERIC }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Throttle by ID, counting unknown IDs too, so guessing can't run unbounded.
  const key = physioCode.toLowerCase();
  const since = new Date(Date.now() - WINDOW_MS).toISOString();
  const { count } = await admin
    .from("physio_auth_attempts")
    .select("*", { count: "exact", head: true })
    .eq("physio_code", key)
    .gte("attempted_at", since);
  if ((count ?? 0) >= MAX_ATTEMPTS) {
    return respond({ error: "Too many attempts. Try again in a few minutes." }, 429);
  }
  const recordFailure = async () => {
    await admin.from("physio_auth_attempts").insert({ physio_code: key });
    // Housekeeping: nothing older than a day is ever needed.
    await admin.from("physio_auth_attempts").delete().lt(
      "attempted_at",
      new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
    );
  };

  const { data: physio } = await admin
    .from("physiotherapists")
    .select("user_id")
    .eq("physio_code", physioCode)
    .maybeSingle();
  const email = physio ? (await admin.auth.admin.getUserById(physio.user_id)).data.user?.email : undefined;

  if (body.action === "reset") {
    await recordFailure(); // resets count toward the same limit (no email bombing)
    if (email) {
      await anon.auth.resetPasswordForEmail(email, { redirectTo: Deno.env.get("PORTAL_URL") });
    }
    return respond({ ok: true }); // identical whether or not the ID exists
  }

  if (body.action === "sign-in") {
    const password = String(body.password ?? "");
    if (!email || !password) {
      await recordFailure();
      return respond({ error: GENERIC }, 401);
    }
    const { data, error } = await anon.auth.signInWithPassword({ email, password });
    if (error || !data.session) {
      await recordFailure();
      return respond({ error: GENERIC }, 401);
    }
    await admin.from("physio_auth_attempts").delete().eq("physio_code", key);
    return respond({
      session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token },
    });
  }

  return respond({ error: "Unknown action." }, 400);
});
