// Backtest des coupons sur les matchs archivés (aucune donnée de match n'est affichée, seulement des totaux).
import { feed } from './feed.mjs';
import { PRESETS, DEFAULT_TUNE, evalPick, oldCandidates, oldGenerate, newGenerate } from './engine.mjs';

const MODES = ['prudent', 'equilibre', 'audacieux'];
const SEEDS = [11, 22, 33];

function prepare(archive) {
  const days = [];
  for (const [day, list] of Object.entries(archive.days || {})) {
    const ms = (list || [])
      .filter((m) => Array.isArray(m.sc) && m.sc.length === 2 && Number.isFinite(m.sc[0]) && Number.isFinite(m.sc[1]))
      .map((m) => ({ id: m.id, lg: m.lg, p: m.p, o: (m.o || []).map(Number), t: m.t, to: Number(m.to), sc: m.sc }));
    if (ms.length) days.push({ day, ms, byId: new Map(ms.map((m) => [m.id, m])) });
  }
  return days.sort((a, b) => a.day.localeCompare(b.day));
}

function score(days, gen) {
  let n = 0, won = 0, odds = 0, ret = 0, pred = 0, daysWith = 0, daysWin = 0, legs = 0, firstWon = 0;
  for (const d of days) {
    const cps = gen(d.ms);
    if (cps.length) daysWith++;
    let any = false;
    for (const [ci, cp] of cps.entries()) {
      const ok = cp.legs.every((l) => {
        const m = d.byId.get(l.id);
        return evalPick(l.pick, m.sc[0], m.sc[1]);
      });
      n++;
      legs += cp.legs.length;
      odds += cp.total;
      pred += cp.prob;
      if (ok) {
        won++;
        ret += cp.total;
        any = true;
        if (ci === 0) firstWon++;
      }
    }
    if (any) daysWin++;
  }
  return {
    coupons: n,
    reussite: n ? (100 * won) / n : 0,
    annonce: n ? (100 * pred) / n : 0,
    coteMoy: n ? odds / n : 0,
    matchsMoy: n ? legs / n : 0,
    rendement: n ? (100 * (ret - n)) / n : 0,
    joursAvecCoupons: (100 * daysWith) / days.length,
    premierGagne: daysWith ? (100 * firstWon) / daysWith : 0,
    joursAvecGain: (100 * daysWin) / days.length,
  };
}

const runOld = (days, c) => {
  const r = SEEDS.map((s) => score(days, (ms) => oldGenerate(oldCandidates(ms, c), c, s)));
  const avg = {};
  for (const k of Object.keys(r[0])) avg[k] = r.reduce((v, x) => v + x[k], 0) / r.length;
  return avg;
};
const runNew = (days, c, tune) => score(days, (ms) => newGenerate(ms, c, tune));

const fmt = (r) =>
  `${String(Math.round(r.coupons)).padStart(5)} coupons | gagnés ${r.reussite.toFixed(1).padStart(5)} % (annoncé ${r.annonce.toFixed(1).padStart(5)} %) | cote moy ${r.coteMoy.toFixed(2).padStart(5)} | ${r.matchsMoy.toFixed(1)} matchs | rendement ${r.rendement.toFixed(1).padStart(6)} % | jours avec coupon ${r.joursAvecCoupons.toFixed(0).padStart(3)} % | jours avec ≥1 gagnant ${r.joursAvecGain.toFixed(0).padStart(3)} % | 1er coupon gagné ${r.premierGagne.toFixed(1).padStart(5)} %`;

const archive = await feed('archive/archive.json');
if (!archive) throw new Error('archive introuvable');
const days = prepare(archive);
const half = Math.floor(days.length / 2);
const train = days.slice(0, half), test = days.slice(half);
console.log(`Jours archivés : ${days.length} (réglage ${train.length} · contrôle ${test.length}) · matchs : ${days.reduce((s, d) => s + d.ms.length, 0)}`);

// Calibration : la probabilité annoncée correspond-elle à la réalité ? (paris simples 1 / X / 2)
for (const [name, fn] of [
  ['PrimaTips', (m, i) => m.p[i] / 100],
  ['Marché', (m, i) => (1 / m.o[i]) / (1 / m.o[0] + 1 / m.o[1] + 1 / m.o[2])],
]) {
  const b = Array.from({ length: 10 }, () => [0, 0, 0]);
  let brier = 0, nb = 0;
  for (const d of days) for (const m of d.ms) {
    if (!(m.p?.length === 3 && m.o?.length === 3 && m.o.every((x) => x > 1.01))) continue;
    const r = m.sc[0] > m.sc[1] ? 0 : m.sc[0] === m.sc[1] ? 1 : 2;
    for (let i = 0; i < 3; i++) {
      const q = Math.min(0.999, Math.max(0, fn(m, i)));
      const k = Math.min(9, Math.floor(q * 10));
      b[k][0]++; b[k][1] += q; b[k][2] += r === i ? 1 : 0;
      brier += (q - (r === i ? 1 : 0)) ** 2; nb++;
    }
  }
  console.log(`\nCalibration ${name} (Brier ${(brier / nb * 3).toFixed(4)}, plus bas = mieux)`);
  for (const [n, q, h] of b) if (n > 50) console.log(`  annoncé ${(100 * q / n).toFixed(0).padStart(3)} % -> réel ${(100 * h / n).toFixed(0).padStart(3)} %  (${n} paris)`);
}

// Réglage du nouveau moteur sur la 1re moitié seulement
// a) Poids PrimaTips / marché : celui qui prédit le mieux les résultats (Brier le plus bas)
function brierBlend(ds, w) {
  let b = 0, n = 0;
  for (const d of ds) for (const m of d.ms) {
    if (!(m.p?.length === 3 && m.o?.length === 3 && m.o.every((x) => x > 1.01))) continue;
    const inv = m.o.map((x) => 1 / x), s = inv[0] + inv[1] + inv[2];
    const sp = m.p[0] + m.p[1] + m.p[2];
    if (sp < 50) continue;
    const r = m.sc[0] > m.sc[1] ? 0 : m.sc[0] === m.sc[1] ? 1 : 2;
    for (let i = 0; i < 3; i++) {
      const q = w * (m.p[i] / sp) + (1 - w) * (inv[i] / s);
      b += (q - (r === i ? 1 : 0)) ** 2;
    }
    n++;
  }
  return b / n;
}
let bestW = 0, bestB = Infinity;
for (let w = 0; w <= 1.0001; w += 0.05) {
  const b = brierBlend(train, w);
  if (b < bestB) [bestW, bestB] = [Math.round(w * 100) / 100, b];
}
console.log(`\nMeilleur mélange (1re moitié) : ${Math.round(bestW * 100)} % PrimaTips + ${Math.round((1 - bestW) * 100)} % marché`);
// b) Valeur minimale exigée (probabilité × cote)
let best = null;
for (const vmin of [0, 0.9, 0.95, 1.0]) {
  const tune = { ...DEFAULT_TUNE, w: bestW, vmin };
  let sc = 0, ok = true;
  for (const mode of MODES) {
    const r = runNew(train, PRESETS.next[mode], tune);
    if (r.joursAvecCoupons < 80) ok = false;
    sc += r.rendement;
  }
  if (ok && (!best || sc > best.sc)) best = { tune, sc };
}
const tune = best ? best.tune : DEFAULT_TUNE;
console.log(`\nRéglage retenu (1re moitié) : poids PrimaTips ${tune.w} · valeur minimale ${tune.vmin}`);

console.log('\n===== CONTRÔLE sur la 2e moitié (jamais vue pendant le réglage) =====');
for (const mode of MODES) {
  console.log(`\n${mode.toUpperCase()}`);
  console.log(`  Ancien moteur, réglages actuels   : ${fmt(runOld(test, PRESETS.old[mode]))}`);
  console.log(`  Nouveau moteur, réglages actuels  : ${fmt(runNew(test, PRESETS.old[mode], tune))}`);
  console.log(`  Ancien moteur, réglages proposés  : ${fmt(runOld(test, PRESETS.next[mode]))}`);
  console.log(`  Nouveau moteur, réglages proposés : ${fmt(runNew(test, PRESETS.next[mode], tune))}`);
}
