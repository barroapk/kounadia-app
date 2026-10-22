// Lecture des données KOUNADIA chiffrées (même format que l'app : "KD1." + AES-256-GCM + gzip).
import crypto from 'node:crypto';
import fs from 'node:fs';
import zlib from 'node:zlib';

const BASE = 'https://raw.githubusercontent.com/barroapk/kfeed';

export function open(text, keyB64) {
  const t = text.trim();
  if (!t.startsWith('KD1.')) return t;
  const raw = Buffer.from(t.slice(4), 'base64');
  const d = crypto.createDecipheriv('aes-256-gcm', Buffer.from(keyB64, 'base64'), raw.subarray(0, 12));
  d.setAuthTag(raw.subarray(raw.length - 16));
  const z = Buffer.concat([d.update(raw.subarray(12, raw.length - 16)), d.final()]);
  return zlib.gunzipSync(z).toString('utf8');
}

/** path = "branche/fichier.json". En local (tests) : dossier KFEED_DIR. */
export async function feed(path) {
  const key = process.env.KD_KEY || '';
  let text;
  if (process.env.KFEED_DIR) {
    const f = `${process.env.KFEED_DIR}/${path}`;
    if (!fs.existsSync(f)) return null;
    text = fs.readFileSync(f, 'utf8');
  } else {
    const r = await fetch(`${BASE}/${path}?v=${Date.now()}`);
    if (!r.ok) return null;
    text = await r.text();
  }
  return JSON.parse(open(text, key));
}
