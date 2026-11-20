// Edge Function `still-here` (migration 20261121000002_still_here.sql; Daniele 2026-11-21 "you still at bc prompt
// after 1 hour that sends a notification"). Called every 5 minutes by pg_cron (pg_net) with the service role key:
// takes the check-ins due a "Still at Black Cabin?" confirm (bc_svc_still_targets marks each one pushed for this hour)
// and sends each one Web Push. The answer itself happens in the game (bc_still_here / Leave); no answer within 30
// minutes checks the player out in the database whether or not this function ever runs.
// Deploy with verify_jwt off like `verb`; the call is refused unless it carries the service role key.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const svc = createClient(URL, SERVICE, { auth: { persistSession: false } });

type Vapid = { public_key: string; private_jwk: { d: string }; subject: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false, detail: "POST only" }, 405);
  if ((req.headers.get("Authorization") ?? "") !== `Bearer ${SERVICE}`) return json({ ok: false, detail: "forbidden" }, 403);
  try {
    const v = await svc.rpc("bc_svc_vapid");
    if (v.error || !v.data) return json({ ok: false, detail: "no vapid keys yet (the verb function makes them)" });
    const vapid = v.data as Vapid;
    const t = await svc.rpc("bc_svc_still_targets");
    if (t.error) return json({ ok: false, detail: t.error.message });
    const targets = (t.data ?? []) as { to: string; log_id: number }[];
    const payload = JSON.stringify({
      title: "Still at Black Cabin?", body: "Open the game and tap Yes to stay checked in. No answer in 30 min checks you out.",
      tag: "bc-still", url: "/",
    });
    let sent = 0;
    for (const tg of targets) {
      const s = await svc.rpc("bc_svc_push_targets", { p_to: tg.to });
      const subs = (s.data ?? []) as { endpoint: string; p256dh: string; auth: string }[];
      let ok = false;
      const gone: string[] = [];
      const details: string[] = [];
      for (const sub of subs) {
        try {
          const r = await webpush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } }, payload,
            { vapidDetails: { subject: vapid.subject, publicKey: vapid.public_key, privateKey: vapid.private_jwk.d },
              TTL: 30 * 60, urgency: "high" },
          );
          ok = true;
          details.push(String(r.statusCode));
        } catch (e) {
          const code = (e as { statusCode?: number }).statusCode ?? 0;
          if (code === 404 || code === 410) gone.push(sub.endpoint);
          details.push(`${code} ${String((e as Error).message ?? e).slice(0, 120)}`);
        }
      }
      if (ok) sent++;
      await svc.rpc("bc_svc_push_result", {
        p_log_id: tg.log_id, p_status: ok ? "sent" : (subs.length && gone.length === subs.length ? "gone" : "failed"),
        p_detail: "still: " + details.join("; "), p_gone_endpoints: gone,
      });
    }
    return json({ ok: true, due: targets.length, sent });
  } catch (e) {
    return json({ ok: false, detail: String((e as Error).message ?? e).slice(0, 200) });
  }
});
