// Metalnini — nommer un admin depuis l'espace admin (réservé au Propriétaire, double authentification comprise).
// Compte existant : nommé tout de suite. Sinon : e-mail d'invitation Supabase (modèle « Invite user »), lien vers l'admin
// où l'invité choisit son mot de passe puis active la double authentification. Tout est journalisé.
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ADMIN_PAGE = "https://pittilloni.github.io/metalnini/admin/";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info" };
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers: cors });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const jwt = req.headers.get("Authorization") ?? "";
  // l'appelant, avec sa propre session : doit être Propriétaire
  const caller = createClient(URL, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: jwt } } });
  const { data: owner } = await caller.rpc("is_owner");
  const { data: { user: me } } = await caller.auth.getUser();
  if (!owner || !me) return reply({ error: "réservé au Propriétaire" }, 403);

  const { email, reason } = await req.json();
  const mail = String(email ?? "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(mail)) return reply({ error: "adresse e-mail invalide" }, 400);
  if (!String(reason ?? "").trim()) return reply({ error: "motif obligatoire" }, 400);

  const sb = createClient(URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let { data: uid } = await sb.rpc("admin_find_user", { p_email: mail });
  let invited = false;
  if (!uid) {
    const { data, error } = await sb.auth.admin.inviteUserByEmail(mail, { redirectTo: ADMIN_PAGE });
    if (error) return reply({ error: error.message }, 500);
    uid = data.user.id; invited = true;
  }
  const { error: e1 } = await sb.from("admins").upsert({ user_id: uid, role: "admin" }, { onConflict: "user_id", ignoreDuplicates: true });
  if (e1) return reply({ error: e1.message }, 500);
  await sb.from("admin_audit_log").insert({ admin_id: me.id, action: "grant_admin", target_user: uid, payload: { email: mail, invited }, reason: String(reason).trim() });
  return reply({ invited });
});
