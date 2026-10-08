// Metalnini — envoi des messages de l'admin par e-mail (SMTP Gmail, port 465 : les ports 25 et 587 sont fermés côté Supabase).
// Appelée uniquement par la base (fonction public.admin_send_message), authentifiée par le secret partagé x-push-secret.
// Secrets de la fonction : PUSH_SECRET, GMAIL_USER, GMAIL_APP_PASSWORD (mot de passe d'application Gmail ; jamais dans le dépôt).
import nodemailer from "npm:nodemailer@6.9.16";

const secret = Deno.env.get("PUSH_SECRET") ?? "";
const user = Deno.env.get("GMAIL_USER") ?? "";
const mailer = nodemailer.createTransport({ host: "smtp.gmail.com", port: 465, secure: true, auth: { user, pass: Deno.env.get("GMAIL_APP_PASSWORD") ?? "" } });
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const APP = "https://pittilloni.github.io/metalnini/proto/";

// e-mail aux couleurs du jeu : noir d'encre, or, os ; paragraphes séparés par une ligne vide ; un bouton qui ouvre l'écran choisi ; comment couper ces e-mails
function html(name: string | null, title: string, body: string, url: string) {
  return `<!doctype html><html lang="fr"><body style="margin:0;background:#0c0b0a;font-family:Helvetica,Arial,sans-serif;color:#f3f0ea">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0c0b0a"><tr><td align="center" style="padding:28px 16px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#161412;border:1px solid #3a2c1c;border-radius:14px">
<tr><td style="padding:26px 24px 8px;text-align:center"><p style="margin:0;font-size:12px;letter-spacing:3px;text-transform:uppercase;color:#e0605a">Metalnini</p>
<h1 style="margin:10px 0 0;font-family:Georgia,serif;font-size:26px;line-height:1.2;color:#f4b243">${esc(title)}</h1></td></tr>
<tr><td style="padding:12px 24px 4px;font-size:16px;line-height:1.55">${name ? `<p style="margin:0 0 10px">Salut ${esc(name)},</p>` : ""}<p style="margin:0">${esc(body).replace(/\n{2,}/g, '</p><p style="margin:12px 0 0">').replace(/\n/g, '<br>')}</p></td></tr>
<tr><td align="center" style="padding:22px 24px 26px"><a href="${esc(url)}" style="display:inline-block;padding:14px 26px;border-radius:10px;background:#eb9a26;color:#1a0f05;font-weight:bold;font-size:15px;letter-spacing:1px;text-transform:uppercase;text-decoration:none">Ouvrir Metalnini</a></td></tr>
</table>
<p style="max-width:520px;margin:14px auto 0;font-size:12px;line-height:1.5;color:#a49e94">Tu reçois cet e-mail parce que tu joues à Metalnini. Pour ne plus en recevoir : dans l'app, Réglages, décoche « Recevoir les nouvelles par e-mail » (<a href="${APP}?vue=reglages" style="color:#a49e94">ouvrir les réglages</a>).</p>
</td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  if (!secret || req.headers.get("x-push-secret") !== secret) return new Response("interdit", { status: 403 });
  const { to, title, body, url } = await req.json() as { to: { email: string; name: string | null }[]; title: string; body: string; url: string };
  let sent = 0, failed = 0;
  for (const r of to ?? []) {
    try {
      await mailer.sendMail({ from: `Metalnini <${user}>`, to: r.email, subject: title,
        text: `${r.name ? `Salut ${r.name},\n\n` : ""}${body}\n\n${url}\n\nPour ne plus recevoir ces e-mails : Réglages de l'app, « Recevoir les nouvelles par e-mail ».`,
        html: html(r.name, title, body, url) });
      sent++;
    } catch (_) { failed++; }
  }
  return Response.json({ sent, failed });
});
