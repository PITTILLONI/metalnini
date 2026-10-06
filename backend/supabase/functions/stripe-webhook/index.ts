// Metalnini — confirmation des paiements Stripe (liens de paiement de la boutique).
// Stripe appelle cette fonction à chaque paiement terminé (événement checkout.session.completed) ; la signature
// (en-tête Stripe-Signature) est vérifiée avec le secret du webhook, puis l'achat est crédité par apply_purchase.
// Secret de la fonction : STRIPE_WEBHOOK_SECRET (jamais dans le dépôt).
import { createClient } from "npm:@supabase/supabase-js@2";

const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const enc = new TextEncoder();

// signature Stripe : t=horodatage,v1=HMAC-SHA256(secret, "t.corps") ; refusée si plus vieille que 5 minutes
async function verified(body: string, header: string): Promise<boolean> {
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=") as [string, string]));
  const t = Number(parts.t);
  if (!t || Math.abs(Date.now() / 1000 - t) > 300) return false;
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(`${t}.${body}`)));
  const hex = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
  const sigs = header.split(",").filter((p) => p.startsWith("v1=")).map((p) => p.slice(3));
  return sigs.some((s) => s.length === hex.length && [...s].every((c, i) => c === hex[i]));
}

Deno.serve(async (req) => {
  const body = await req.text();
  if (!secret || !(await verified(body, req.headers.get("stripe-signature") ?? ""))) return new Response("signature invalide", { status: 400 });
  const event = JSON.parse(body);
  if (event.type !== "checkout.session.completed") return Response.json({ ignored: event.type });
  const s = event.data.object;
  if (s.payment_status !== "paid" || s.currency !== "eur" || !s.client_reference_id) return Response.json({ ignored: "pas payé ou sans achat" });
  const { data, error } = await sb.rpc("apply_purchase", { p_id: s.client_reference_id, p_session: s.id, p_cents: s.amount_total });
  // une erreur renvoie 500 : Stripe réessaie plus tard
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ result: data });
});
