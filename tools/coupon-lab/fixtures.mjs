// Régénère mobile/test/fixtures/coupon_expected.json avec le moteur du labo (identique à coupon_engine.dart).
// Usage : node tools/coupon-lab/fixtures.mjs [--check]
import fs from 'node:fs';
import { newCandidates, newSearch } from './engine.mjs';

const dir = new URL('../../mobile/test/fixtures/', import.meta.url);
const raw = JSON.parse(fs.readFileSync(new URL('coupon_matches.json', dir), 'utf8'));
const matches = raw.map((m) => ({ id: m.id, p: m.probs, o: m.odds, t: m.tip, to: m.tipOdd }));
const base = { win: true, draw: false, dc: true };
const presets = {
  safe: { ...base, totalMin: 1.5, totalMax: 2.5, countMin: 2, countMax: 3, oddMin: 1.1, oddMax: 1.7, probMin: 70, probMax: 95 },
  balanced: { ...base, totalMin: 2.5, totalMax: 5, countMin: 2, countMax: 4, oddMin: 1.25, oddMax: 2.2, probMin: 58, probMax: 95 },
  bold: { ...base, totalMin: 6, totalMax: 15, countMin: 3, countMax: 6, oddMin: 1.4, oddMax: 3.2, probMin: 40, probMax: 95, draw: true },
};
const out = {};
for (const [k, c] of Object.entries(presets)) {
  const cands = newCandidates(matches, c);
  const first = newSearch(cands, c);
  const second = newSearch(cands, c, new Set(first.map((x) => x.sg)));
  out[k] = { first: first.map((x) => [x.sg, x.prob]), second: second.map((x) => [x.sg, x.prob]) };
}
const f = new URL('coupon_expected.json', dir);
if (process.argv.includes('--check')) {
  const old = JSON.parse(fs.readFileSync(f, 'utf8'));
  const same = JSON.stringify(old) === JSON.stringify(out);
  console.log(same ? 'IDENTIQUE' : 'DIFFERENT');
  if (!same) for (const k of Object.keys(out)) console.log(k, JSON.stringify(old[k]).slice(0, 200), '\n =>', JSON.stringify(out[k]).slice(0, 200));
} else {
  fs.writeFileSync(f, JSON.stringify(out));
  console.log('écrit', f.pathname);
}
