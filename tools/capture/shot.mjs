// Capture du prototype en taille téléphone (Chrome sans interface, protocole DevTools).
// Prérequis : serveur local à la racine du dépôt (`python3 -m http.server 8765`) et Google Chrome installé.
// usage : node tools/capture/shot.mjs LARGEUR HAUTEUR sortie.png ["js exécuté avant la capture"] [user-agent]
// Variables : SEED = script injecté avant le chargement (état local, fausse API), WAIT = attente après le script (ms, 1500 par défaut).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const [W, H, out, pre = '', ua = ''] = process.argv.slice(2);
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'metalnini-chrome-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=9333', '--user-data-dir=' + profile, '--hide-scrollbars', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let tgt; for (let i = 0; i < 50 && !tgt; i++) { await sleep(200); try { tgt = (await (await fetch('http://127.0.0.1:9333/json')).json()).find(t => t.type === 'page'); } catch {} }
const ws = new WebSocket(tgt.webSocketDebuggerUrl); await new Promise(r => ws.onopen = r);
let id = 0; const pend = {}; ws.onmessage = e => { const m = JSON.parse(e.data); if (pend[m.id]) { pend[m.id](m); delete pend[m.id]; } };
const send = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
await send('Emulation.setDeviceMetricsOverride', { width: +W, height: +H, deviceScaleFactor: 2, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true });
await send('Page.enable');
if (process.env.SEED) await send('Page.addScriptToEvaluateOnNewDocument', { source: process.env.SEED });
if (ua) { await send('Page.addScriptToEvaluateOnNewDocument', { source: "addEventListener('beforeinstallprompt',e=>e.stopImmediatePropagation(),true)" }); await send('Emulation.setUserAgentOverride', { userAgent: ua, platform: 'iPhone' }); }
await send('Page.navigate', { url: 'http://localhost:8765/proto/' }); await sleep(3000);
if (pre) { const r = await send('Runtime.evaluate', { expression: pre, awaitPromise: true, returnByValue: true }); console.log(JSON.stringify(r.result?.result?.value ?? r.result)); await sleep(+(process.env.WAIT || 1500)); }
const s = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(out, Buffer.from(s.result.data, 'base64'));
ws.close(); const gone = new Promise(r => chrome.once('exit', r)); chrome.kill(); await gone;
fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
