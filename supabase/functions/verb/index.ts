// Edge Function `verb` (docs/design/08b-presence-api.md §3.3, §4).
//   POST {to, kind, payload}  with the player's JWT: records the verb through bc_send_verb (as that player, so RLS
//                             and limits apply) and, when the push budget allows, sends a Web Push to the receiver.
//   POST {action:"public_key"}: the VAPID public key (applicationServerKey) for the browser's push subscription.
// VAPID keys are created here on the first run and kept in private.vapid; the private key never leaves Supabase.
// Deployed with verify_jwt off so the browser's CORS preflight passes; every verb call is checked by the RPC itself.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const svc = createClient(URL, SERVICE, { auth: { persistSession: false } });

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

function b64u(buf: Uint8Array): string {
  let s = "";
  for (const b of buf) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function unb64u(s: string): Uint8Array {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

type Vapid = { public_key: string; private_jwk: { d: string }; subject: string };
let vapidCache: Vapid | null = null;

async function vapid(): Promise<Vapid> {
  if (vapidCache) return vapidCache;
  const got = await svc.rpc("bc_svc_vapid");
  if (got.error) throw new Error("vapid read: " + got.error.message);
  if (got.data) return (vapidCache = got.data as Vapid);
  const kp = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const jwk = await crypto.subtle.exportKey("jwk", kp.privateKey);
  const x = unb64u(jwk.x!), y = unb64u(jwk.y!);
  const pub = new Uint8Array(65);
  pub[0] = 4; pub.set(x, 1); pub.set(y, 33);
  const set = await svc.rpc("bc_svc_vapid_set", { p_public: b64u(pub), p_private: jwk });
  if (set.error) throw new Error("vapid write: " + set.error.message);
  return (vapidCache = set.data as Vapid);       // on a race the row written first wins
}

const TEXT: Record<string, (n: string) => string> = {
  wave: (n) => `${n} waved at you at Black Cabin`,
  cheers: (n) => `${n} raised a glass to you`,
  drink: (n) => `${n} sent you a drink`,
  phrase: (n) => `${n} sent you a message`,
};

async function sendPush(to: string, fromName: string, kind: string, logId: number): Promise<boolean> {
  const v = await vapid();
  const t = await svc.rpc("bc_svc_push_targets", { p_to: to });
  const subs = (t.data ?? []) as { endpoint: string; p256dh: string; auth: string }[];
  const payload = JSON.stringify({
    title: "Black Cabin", body: (TEXT[kind] ?? ((n: string) => `${n} said hi`))(fromName || "Someone"),
    tag: "bc-verb", url: "/",
  });
  let ok = false;
  const gone: string[] = [];
  const details: string[] = [];
  for (const s of subs) {
    try {
      const r = await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload,
        { vapidDetails: { subject: v.subject, publicKey: v.public_key, privateKey: v.private_jwk.d }, TTL: 4 * 3600, urgency: "normal" },
      );
      ok = true;
      details.push(String(r.statusCode));
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode ?? 0;
      if (code === 404 || code === 410) gone.push(s.endpoint);
      details.push(`${code} ${String((e as Error).message ?? e).slice(0, 120)}`);
    }
  }
  await svc.rpc("bc_svc_push_result", {
    p_log_id: logId, p_status: ok ? "sent" : (subs.length && gone.length === subs.length ? "gone" : "failed"),
    p_detail: details.join("; "), p_gone_endpoints: gone,
  });
  return ok;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, reason: "server", detail: "POST only" }, 405);
  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { return json({ ok: false, reason: "server", detail: "bad json" }, 400); }
  try {
    if (body.action === "public_key") return json({ ok: true, public_key: (await vapid()).public_key });
    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
    const r = await user.rpc("bc_send_verb", { p_to: body.to, p_kind: body.kind, p_payload: body.payload ?? {} });
    if (r.error) {
      const authFail = /JWT|jwt|auth/i.test(r.error.message);
      return json({ ok: false, reason: authFail ? "auth" : "server", detail: r.error.message }, authFail ? 401 : 200);
    }
    const d = r.data as Record<string, unknown>;
    let pushed = false;
    if (d?.ok && d.push && d.push_log_id) {
      pushed = await sendPush(String(body.to), String(d.from_name ?? ""), String(body.kind), Number(d.push_log_id));
    }
    return json({ ok: d?.ok ?? false, reason: d?.reason, event_id: d?.event_id, pushed });
  } catch (e) {
    return json({ ok: false, reason: "server", detail: String((e as Error).message ?? e).slice(0, 200) });
  }
});
