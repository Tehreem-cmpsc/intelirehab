// Clinic-admin-only physiotherapist management, run with the service role so
// the browser never creates accounts or swaps sessions.
//
//   create: makes the auth user (server-generated temporary password,
//           email pre-confirmed) and the Pending physiotherapists row as one
//           unit — if the row fails, the auth user is rolled back.
//   remove: deletes the row AND the login, scoped to the caller's clinic.
//
// Deploy: supabase functions deploy manage-physiotherapist
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeadersFor, json } from "../_shared/cors.ts";

const LICENSE = /^PMC-\d{5}$/i;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Same rules as AddPhysiotherapistModal - the form is a convenience, this is the enforcement.
const NAME = /^[\p{L}\p{M}.'\u2019\s-]{3,}$/u;
const PHYSIO_ID = /^(?=.{6,}$)(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d_-]+$/;
const CNIC = /^\d{5}-\d{7}-\d{1}$/;

// 14 chars, always at least one letter and one digit (meets the portal's
// own password rule); ambiguous characters left out so it's easy to read out.
function temporaryPassword(): string {
  const letters = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
  const digits = "23456789";
  const all = letters + digits;
  const pick = (set: string) => set[crypto.getRandomValues(new Uint32Array(1))[0] % set.length];
  const chars = [pick(letters), pick(digits), ...Array.from({ length: 12 }, () => pick(all))];
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.getRandomValues(new Uint32Array(1))[0] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}

Deno.serve(async (req) => {
  const cors = corsHeadersFor(req);
  const respond = (body: unknown, status = 200) => json(body, status, cors);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return respond({ error: "Please sign in again." }, 401);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // The clinic comes from who is calling, never from the request body.
  const { data: clinic } = await admin
    .from("clinics")
    .select("id")
    .eq("admin_user_id", user.id)
    .maybeSingle();
  if (!clinic) return respond({ error: "Only a clinic administrator can do this." }, 403);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid request." }, 400);
  }

  if (body.action === "create") {
    const name = String(body.name ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const physioCode = String(body.physioId ?? "").trim();
    const license = String(body.license ?? "").trim();
    const years = Number(body.yearsExperience);
    const joining = new Date(String(body.joiningDate ?? ""));
    if (
      !NAME.test(name) ||
      !PHYSIO_ID.test(physioCode) ||
      !EMAIL.test(email) ||
      !LICENSE.test(license) ||
      !CNIC.test(String(body.cnic ?? "").trim()) ||
      String(body.specialization ?? "").trim().length < 3 ||
      String(body.qualification ?? "").trim().length < 2 ||
      !Number.isInteger(years) || years < 0 || years > 60 ||
      isNaN(joining.getTime()) || joining.getTime() > Date.now()
    ) {
      return respond({ error: "Some details are missing or invalid." }, 400);
    }

    const password = temporaryPassword();
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: name },
    });
    if (createErr || !created.user) {
      const exists = /already|registered|exists/i.test(createErr?.message ?? "");
      return respond(
        { error: exists ? "An account with this email already exists." : "Unable to create the account." },
        exists ? 409 : 500,
      );
    }

    const { data: row, error: insertErr } = await admin
      .from("physiotherapists")
      .insert({
        user_id: created.user.id,
        clinic_id: clinic.id,
        physio_code: physioCode,
        full_name: name,
        specialization: String(body.specialization ?? "").trim(),
        license_number: license,
        cnic: String(body.cnic ?? "").trim(),
        qualification: String(body.qualification ?? "").trim(),
        years_experience: years,
        joining_date: body.joiningDate,
        status: "Pending",
        must_reset_password: true,
      })
      .select()
      .single();

    if (insertErr) {
      await admin.auth.admin.deleteUser(created.user.id); // no orphaned login
      const dup = insertErr.code === "23505";
      return respond(
        { error: dup ? "That physiotherapist ID is already in use." : "Unable to save the physiotherapist." },
        dup ? 409 : 500,
      );
    }

    await admin.from("activity_log").insert({
      clinic_id: clinic.id,
      message: `${name} was added to the roster and is awaiting approval.`,
    });
    return respond({ physio: row, temporaryPassword: password });
  }

  if (body.action === "remove") {
    const { data: row } = await admin
      .from("physiotherapists")
      .select("id, user_id, full_name")
      .eq("id", body.id)
      .eq("clinic_id", clinic.id)
      .maybeSingle();
    if (!row) return respond({ error: "Physiotherapist not found in your clinic." }, 404);

    // Deleting the login cascades to the row; patients' physio_id is set null.
    const { error } = await admin.auth.admin.deleteUser(row.user_id);
    if (error) return respond({ error: "Unable to remove the physiotherapist." }, 500);

    await admin.from("activity_log").insert({
      clinic_id: clinic.id,
      message: `${row.full_name ?? "A physiotherapist"} was removed from the roster.`,
    });
    return respond({ ok: true });
  }

  return respond({ error: "Unknown action." }, 400);
});
