// Metalnini — envoi des notifications push (Web Push, clés VAPID).
// Appelée uniquement par la base (fonction public.send_push), authentifiée par le secret partagé x-push-secret.
// Secrets de la fonction : VAPID_PUBLIC, VAPID_PRIVATE, PUSH_SECRET (jamais dans le dépôt).
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const secret = Deno.env.get("PUSH_SECRET") ?? "";
webpush.setVapidDetails("https://pittilloni.github.io/metalnini/", Deno.env.get("VAPID_PUBLIC")!, Deno.env.get("VAPID_PRIVATE")!);
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  if (!secret || req.headers.get("x-push-secret") !== secret) return new Response("interdit", { status: 403 });
  const { user_id, title, body, url } = await req.json();
  const { data: subs, error } = await sb.from("push_subscriptions").select("endpoint, p256dh, auth").eq("user_id", user_id);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  let sent = 0;
  for (const s of subs ?? []) {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({ title, body, url: url ?? "./" }), { TTL: 86400 });
      sent++;
    } catch (e) {
      // appareil désabonné ou expiré : on l'oublie
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) await sb.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
    }
  }
  return Response.json({ sent });
});
