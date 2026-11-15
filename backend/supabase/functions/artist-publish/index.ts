// Metalnini — « Publier » une demande d'artiste préparée par l'agent cloud (artist_jobs « ready ») : fusionne sa branche dans main
// (le push déploie les pages), applique la seed de main sur la base, supprime la branche, puis prévient les demandeurs.
// Réservé à l'équipe d'admin (double authentification comprise, vérifiée avec la session de l'appelant). Secret : GITHUB_TOKEN
// (jeton GitHub limité au dépôt metalnini : Contents en écriture).
import { createClient } from "npm:@supabase/supabase-js@2";
import postgres from "npm:postgres@3";

const URL = Deno.env.get("SUPABASE_URL")!;
const REPO = "https://api.github.com/repos/PITTILLONI/metalnini";
const gh = (path: string, init: RequestInit = {}) => fetch(REPO + path, { ...init, headers: { Authorization: `Bearer ${Deno.env.get("GITHUB_TOKEN")}`,
  Accept: "application/vnd.github+json", "User-Agent": "metalnini-admin", "Content-Type": "application/json", ...(init.headers ?? {}) } });
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info" };
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers: cors });

// conflit avec main : reprise automatique par GitHub (.github/workflows/reprise-artiste.yml) ; la branche reprise/<branche>
// part de main ; si la reprise a échoué, elle porte REPRISE_ECHEC.txt (la raison), qu'on montre puis qu'on efface
async function reprise(branch: string): Promise<string> {
  const rep = `reprise/${branch}`;
  if ((await gh(`/git/ref/heads/${rep}`)).ok) {
    const f = await gh(`/contents/REPRISE_ECHEC.txt?ref=${encodeURIComponent(rep)}`, { headers: { Accept: "application/vnd.github.raw+json" } });
    if (!f.ok) return "mise à jour automatique depuis main en cours : reclique « Publier » dans 3 minutes";
    const why = (await f.text()).trim();
    await gh(`/git/refs/heads/${rep}`, { method: "DELETE" });
    return `reprise automatique impossible : ${why}`;
  }
  const main = await gh("/git/ref/heads/main");
  if (!main.ok) return `GitHub ${main.status} : main introuvable`;
  const c = await gh("/git/refs", { method: "POST", body: JSON.stringify({ ref: `refs/heads/${rep}`, sha: (await main.json()).object.sha }) });
  if (!c.ok) return `reprise impossible à lancer (GitHub ${c.status})`;
  return "la branche avait pris du retard sur main : mise à jour automatique lancée, reclique « Publier » dans 3 minutes";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const caller = createClient(URL, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: admin } = await caller.rpc("is_admin");
  if (!admin) return reply({ error: "réservé à l'admin" }, 403);

  const { job } = await req.json();
  const sb = createClient(URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: j } = await sb.from("artist_jobs").select("*").eq("id", job).single();
  if (!j || j.status !== "ready" || !j.branch) return reply({ error: "pas prête à publier" }, 409);

  // fusion de la branche de l'agent dans main (201 : fusionnée, 204 : déjà dedans)
  const m = await gh("/merges", { method: "POST", body: JSON.stringify({ base: "main", head: j.branch, commit_message: `${j.artist} ajouté (demande de joueurs, préparé par l'agent)` }) });
  if (m.status === 409) return reply({ error: await reprise(j.branch) }, 409);
  if (m.status !== 201 && m.status !== 204) return reply({ error: `GitHub ${m.status} : ${(await m.text()).slice(0, 200)}` }, 502);

  // seed de main (rejouable : fiches, cartes, classeurs ; ne touche ni aux collections ni à l'activation)
  const s = await gh("/contents/backend/supabase/seed.sql?ref=main", { headers: { Accept: "application/vnd.github.raw+json" } });
  if (!s.ok) return reply({ error: `seed introuvable (GitHub ${s.status})` }, 502);
  const db = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 1 });   // une seule connexion : la seed ouvre sa propre transaction
  try { await db.unsafe(await s.text()); } catch (e) { return reply({ error: "seed : " + String((e as Error).message ?? e).slice(0, 300) }, 500); }
  finally { await db.end(); }

  await gh(`/git/refs/heads/${j.branch}`, { method: "DELETE" });
  // statut « published » et demandeurs prévenus, avec la session de l'admin (journalisé)
  const { data: told, error } = await caller.rpc("admin_job_published", { p_job: job });
  if (error) return reply({ error: error.message }, 500);
  return reply({ told });
});
