import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigins = new Set([
  "https://tordtaris.github.io",
  "https://mars-land-explorer.vercel.app",
  "https://mars-land-explorer-git-feature-systems-oversig-e30bfa-tordtaris.vercel.app",
  ...(Deno.env.get("SITE_ORIGINS") ?? "").split(","),
  Deno.env.get("SITE_ORIGIN") ?? "",
].map((value) => value.trim()).filter(Boolean));

function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return true;
  if (allowedOrigins.has(origin)) return true;
  try {
    const parsed = new URL(origin);
    return parsed.protocol === "https:" && parsed.hostname.endsWith("-tordtaris.vercel.app");
  } catch {
    return false;
  }
}
function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (origin && isAllowedOrigin(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}
const json = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}
function fromBase64(value: string): Uint8Array {
  return Uint8Array.from(atob(value), c => c.charCodeAt(0));
}
async function derive(password: string, salt: Uint8Array): Promise<string> {
  const material = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: 310000 }, material, 256);
  return toBase64(new Uint8Array(bits));
}
function safeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
function validPassword(value: unknown): value is string {
  return typeof value === "string" && value.length >= 10 && value.length <= 128;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  const respond = (body: unknown, status = 200) => json(body, status, origin);
  if (req.method === "OPTIONS") {
    if (!isAllowedOrigin(origin)) return new Response("Origin not allowed", { status: 403 });
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);
  if (!isAllowedOrigin(origin)) return respond({ error: "Origin not allowed" }, 403);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceKey) return respond({ error: "M-003 security service is not configured" }, 503);

    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return respond({ error: "Sign in is required" }, 401);
    const token = authorization.slice(7);
    const authClient = createClient(supabaseUrl, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) return respond({ error: "Session expired. Please sign in again." }, 401);
    const userId = authData.user.id;
    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const { data: claim, error: claimError } = await admin.from("world_claims")
      .select("owner_id").eq("parcel_id", "M-003").maybeSingle();
    if (claimError) return respond({ error: "Unable to verify M-003 ownership" }, 503);
    if (!claim || claim.owner_id !== userId) return respond({ error: "M-003 owner authorization required" }, 403);

    const body = await req.json();
    const action = String(body.action ?? "");
    const { data: credential, error: credentialError } = await admin.from("m003_access_credentials")
      .select("user_id,password_salt,password_hash,failed_attempts,locked_until")
      .eq("user_id", userId).maybeSingle();
    if (credentialError) return respond({ error: "Unable to read M-003 security settings. Apply migration 022." }, 503);

    if (action === "status") return respond({ has_password: Boolean(credential) });
    if (action === "setup") {
      if (credential) return respond({ error: "A security password is already configured. Enter your password to continue." }, 409);
      if (!validPassword(body.password)) return respond({ error: "Use a password between 10 and 128 characters." }, 400);
      if (body.password !== body.confirm_password) return respond({ error: "The passwords do not match." }, 400);
      const salt = crypto.getRandomValues(new Uint8Array(16));
      const passwordHash = await derive(body.password, salt);
      const { error } = await admin.from("m003_access_credentials").insert({
        user_id: userId, password_salt: toBase64(salt), password_hash: passwordHash,
        failed_attempts: 0, locked_until: null,
      });
      if (error) return respond({ error: "Could not save the security password. Please retry." }, 409);
      return respond({ ok: true, message: "M-003 security password configured." });
    }
    if (action !== "verify") return respond({ error: "Unsupported security action." }, 400);
    if (!credential) return respond({ needs_setup: true });
    if (credential.locked_until && new Date(credential.locked_until).getTime() > Date.now()) {
      return respond({ error: "Security gate temporarily locked. Try again later." }, 423);
    }
    if (typeof body.password !== "string" || body.password.length > 128) return respond({ error: "Incorrect security password." }, 401);
    const candidate = fromBase64(await derive(body.password, fromBase64(credential.password_salt)));
    const stored = fromBase64(credential.password_hash);
    if (!safeEqual(candidate, stored)) {
      const { data: lockRows, error: lockError } = await admin.rpc("m003_record_failed_attempt", {
        p_user_id: userId,
      });
      if (lockError) return respond({ error: "Unable to update M-003 security lockout. Please retry." }, 503);
      const lockState = Array.isArray(lockRows) ? lockRows[0] : lockRows;
      const isLocked = Boolean(lockState?.is_locked);
      return respond({
        error: isLocked ? "Too many attempts. Access is locked for 15 minutes." : "Incorrect security password.",
      }, isLocked ? 423 : 401);
    }
    await admin.from("m003_access_credentials").update({
      failed_attempts: 0, locked_until: null, updated_at: new Date().toISOString(),
    }).eq("user_id", userId);
    const { data: floors, error: floorsError } = await admin.from("m003_private_base")
      .select("floor_no,room_name,description,system_status").order("floor_no");
    if (floorsError) return respond({ error: "Unable to load underground base records." }, 503);
    const { data: archive, error: archiveError } = await admin.rpc("get_m003_confidential_archive");
    if (archiveError) return respond({ error: "Unable to load the M-003 confidential archive." }, 503);
    return respond({ ok: true, data: floors ?? [], confidential_archive: archive ?? null });
  } catch (error) {
    console.error("M-003 access function error", error);
    return respond({ error: "M-003 security service encountered an unexpected error." }, 500);
  }
});
