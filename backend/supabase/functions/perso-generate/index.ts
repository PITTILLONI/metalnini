// Metalnini — fabrication d'une carte perso (commande perso_orders), appelée par la base (public.perso_kick) avec le secret partagé.
// Deux étapes, chacune dans son propre appel (une fonction a un temps limité) : « paid » → carte de base (photo de profil + style
// The Priest) → « base » ; « base » → version Légendaire, rangée dans le stockage privé perso/<id>/legendaire.jpg → « ready ».
// L'équipe d'admin valide ensuite dans l'admin (la carte est alors offerte). Secrets : PUSH_SECRET, KREA_API_KEY.
import { createClient } from "npm:@supabase/supabase-js@2";

const secret = Deno.env.get("PUSH_SECRET") ?? "";
const krea = Deno.env.get("KREA_API_KEY") ?? "";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const SELF = Deno.env.get("SUPABASE_URL") + "/functions/v1/perso-generate";
const STYLE = "https://pittilloni.github.io/metalnini/assets/da/creas/morello-base.jpg";
const LEGEND = "Edit this tarot card. Keep the person, their face, the pose, the props, the layout and all the text exactly as they are. " +
  "Turn it into a LEGENDARY ultra-rare card: invert the engraving into a negative, the whole card is glossy pitch-black foil and every engraved line of the illustration is rendered in glowing crimson red and molten gold ink, keeping the face clearly lit and readable. The halo becomes a burning ring of fire, glowing embers and sparks float around the person, the ornate frame is black obsidian with blood-red gemstones in the corners, subtle dark holographic sheen. Ominous, precious, unmistakably the rarest card.";

// une image Krea (Nano Banana Pro) : lancement, attente, adresse du résultat
async function generate(prompt: string, images: string[]): Promise<string> {
  const h = { Authorization: `Bearer ${krea}`, "Content-Type": "application/json" };
  let job: Record<string, unknown> = {};
  for (let i = 0; i < 20; i++) {
    const r = await fetch("https://api.krea.ai/generate/image/google/nano-banana-pro", { method: "POST", headers: h,
      body: JSON.stringify({ prompt, aspect_ratio: "2:3", resolution: "1K", image_urls: images }) });
    if (r.status === 429) { await new Promise((ok) => setTimeout(ok, 10000)); continue; }
    if (r.status === 402) throw new Error("solde Krea insuffisant");
    if (!r.ok) throw new Error(`Krea ${r.status} : ${(await r.text()).slice(0, 200)}`);
    job = await r.json(); break;
  }
  const id = (job.job_id ?? job.id) as string;
  if (!id) throw new Error("Krea : pas de job");
  for (let i = 0; i < 60; i++) {
    await new Promise((ok) => setTimeout(ok, 3000));
    const j = await (await fetch(`https://api.krea.ai/jobs/${id}`, { headers: h })).json();
    if (j.status === "completed") { const u = j.result?.urls?.[0]; if (!u) throw new Error("Krea : job sans image"); return u; }
    if (j.status === "failed" || j.status === "cancelled") throw new Error(`Krea : job ${j.status}`);
  }
  throw new Error("Krea : délai dépassé");
}

async function step(orderId: string) {
  const { data: o } = await sb.from("perso_orders").select("*").eq("id", orderId).single();
  if (!o || !["paid", "base"].includes(o.status)) return;
  if (o.status === "paid") {
    const { data: s } = await sb.storage.from("avatars").createSignedUrl(o.avatar_path, 3600);
    if (!s) throw new Error("photo de profil introuvable");
    const url = await generate(
      `Create a vintage gothic tarot card. Use the first image ONLY for the likeness of the person in the photo: keep their face, hair, facial hair, glasses or makeup if any, recognizable, half-body, a confident rock pose. ` +
      `Use the second image ONLY as the style reference: dense fine engraved cross-hatching, ornate black frame with corner flourishes, sun and crescent moon at the top, aged parchment, palette of dark red, black and antique gold, a dark red halo behind the head. ` +
      `Do not copy the musician of the second image, only the style. Props: an electric guitar or a microphone, black candles. Roman numeral "XIII" at the top. Bottom cartouche: large title "${o.nickname}", smaller subtitle "Carte perso · Metalnini". No other text, no logos, no signature.`,
      [s.signedUrl, STYLE]);
    await sb.from("perso_orders").update({ status: "base", base_url: url, tries: o.tries + 1, updated_at: new Date().toISOString() }).eq("id", orderId);
    await fetch(SELF, { method: "POST", headers: { "Content-Type": "application/json", "x-push-secret": secret }, body: JSON.stringify({ order: orderId }) });
    return;
  }
  // « base » : la Légendaire, rangée dans le stockage privé, puis la fiche de la carte
  const url = await generate(LEGEND, [o.base_url]);
  const img = new Uint8Array(await (await fetch(url)).arrayBuffer());
  const mid = "p-" + orderId.slice(0, 8);
  const { error: up } = await sb.storage.from("perso").upload(`${mid}/legendaire.jpg`, img, { contentType: "image/png", upsert: true });
  if (up) throw new Error("stockage : " + up.message);
  await sb.from("musicians").upsert({ id: mid, name: o.nickname, band: "Carte perso", arcana_title: o.nickname, arcana_number: "XIII",
    instruments: [], subgenre: "Carte perso", active: false, perso: true });
  await sb.from("cards").upsert({ musician_id: mid, rarity: "legendaire", image_path: `${mid}/legendaire.jpg` });
  await sb.from("perso_orders").update({ status: "ready", musician_id: mid, updated_at: new Date().toISOString() }).eq("id", orderId);
}

Deno.serve(async (req) => {
  if (!secret || req.headers.get("x-push-secret") !== secret) return new Response("interdit", { status: 403 });
  const { order } = await req.json();
  // la génération continue après la réponse (la base n'attend pas)
  // @ts-ignore EdgeRuntime existe sur Supabase
  EdgeRuntime.waitUntil(step(order).catch(async (e) => {
    await sb.from("perso_orders").update({ status: "error", error: String(e?.message ?? e).slice(0, 300), updated_at: new Date().toISOString() }).eq("id", order);
  }));
  return Response.json({ ok: true });
});
