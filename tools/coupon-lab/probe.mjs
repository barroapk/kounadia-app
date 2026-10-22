// Décrit la FORME des données (noms des champs, types, nombres) sans afficher leur contenu.
import { feed } from './feed.mjs';

const FILES = ['archive/archive.json', 'archive/backtest.json', 'scores/scores.json', 'markets/markets.json',
  'pronos/history.json', 'pronos/picks.json', 'pronos/today.json', 'vip/vip_history.json'];

function shape(v, depth, seen) {
  if (v === null) return 'null';
  if (Array.isArray(v)) {
    if (!v.length) return '[]';
    if (depth > 5) return `[${v.length}]`;
    return { [`[${v.length}]`]: merge(v.slice(0, 200).map((x) => shape(x, depth + 1, seen))) };
  }
  if (typeof v === 'object') {
    const keys = Object.keys(v);
    // Dictionnaire indexé par identifiants/dates : on résume.
    if (keys.length > 30 && keys.every((k) => /^[\d-]+$/.test(k))) {
      return { [`{${keys.length} clés comme ${keys[0].replace(/\d/g, '9')}}`]: merge(keys.slice(0, 100).map((k) => shape(v[k], depth + 1, seen))) };
    }
    if (depth > 5) return `{${keys.length}}`;
    const o = {};
    for (const k of keys) o[k] = shape(v[k], depth + 1, seen);
    return o;
  }
  if (typeof v === 'number') return Number.isInteger(v) ? 'int' : 'float';
  if (typeof v === 'string') return /^\d{4}-\d\d-\d\d/.test(v) ? 'date' : /^[A-Z0-9]{1,4}$/.test(v) ? `code:${v}` : 'str';
  return typeof v;
}

function merge(list) {
  const out = {};
  for (const s of list) {
    if (typeof s !== 'object' || s === null) {
      const k = typeof s === 'string' && s.startsWith('code:') ? 'code' : s;
      out[k] = out[k] || new Set();
      if (typeof s === 'string' && s.startsWith('code:')) out[k].add(s.slice(5));
      continue;
    }
    for (const [k, v] of Object.entries(s)) (out[`.${k}`] ||= []).push(v);
  }
  const r = {};
  for (const [k, v] of Object.entries(out)) {
    if (v instanceof Set) r[k] = v.size ? `codes(${[...v].slice(0, 15).join(',')}${v.size > 15 ? ',…' : ''})` : k;
    else r[k] = merge(v);
  }
  const ks = Object.keys(r);
  return ks.length === 1 && !ks[0].startsWith('.') ? r[ks[0]] : r;
}

for (const f of FILES) {
  try {
    const d = await feed(f);
    console.log(`\n===== ${f} =====`);
    console.log(d == null ? 'absent' : JSON.stringify(shape(d, 0), null, 1).slice(0, 6000));
  } catch (e) {
    console.log(`\n===== ${f} ===== erreur ${e.message}`);
  }
}
