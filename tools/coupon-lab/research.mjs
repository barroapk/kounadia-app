// Recherche « coups sûrs » : jusqu'où peut-on monter le taux de réussite, et à quel prix ?
// Tout est réglé sur la 1re moitié des jours puis vérifié sur la 2e (contre-backtest).
import { feed } from './feed.mjs';
import { evalPick } from './engine.mjs';

const archive = await feed('archive/archive.json');
const days = Object.entries(archive.days || {}).sort((a, b) => a[0].localeCompare(b[0]));
const half = Math.floor(days.length / 2);

// Un pari = l'issue la plus probable d'un match (1, 2, 1X, X2, 12) selon le marché.
function picks(list) {
  const out = [];
  for (const m of list || []) {
    if (!Array.isArray(m.sc) || m.sc.length !== 2 || !Array.isArray(m.o) || m.o.length !== 3) continue;
    const o = m.o.map(Number);
    if (!o.every((x) => x > 1.01)) continue;
    const inv = o.map((x) => 1 / x), s = inv[0] + inv[1] + inv[2], q = inv.map((x) => x / s);
    const p = Array.isArray(m.p) && m.p.length === 3 ? m.p.map(Number) : null;
    const sp = p ? p[0] + p[1] + p[2] : 0;
    const ps = (i) => (p && sp > 50 ? p[i] / sp : null);
    const opts = [
      ['1', q[0], o[0], ps(0)], ['2', q[2], o[2], ps(2)],
      ['1X', q[0] + q[1], 0.98 / (inv[0] + inv[1]), p ? ps(0) + ps(1) : null],
      ['X2', q[1] + q[2], 0.98 / (inv[1] + inv[2]), p ? ps(1) + ps(2) : null],
      ['12', q[0] + q[2], 0.98 / (inv[0] + inv[2]), p ? ps(0) + ps(2) : null],
    ];
    for (const [pick, qq, rawOdd, pp] of opts) {
      const t = String(m.t || '').toUpperCase();
      const agree = t === pick || (t.length === 1 && pick.length === 2 && pick.includes(t)) || (t.length === 2 && pick.length === 1 && t.includes(pick));
      const odd = t === pick && Number(m.to) > 1.01 ? Number(m.to) : Math.round(rawOdd * 100) / 100;
      if (odd <= 1.01) continue; // pari introuvable chez un bookmaker
      out.push({ id: m.id, lg: m.lg, pick, q: qq, odd, ps: pp, agree,
        won: evalPick(pick, m.sc[0], m.sc[1]), single: pick.length === 1 });
    }
  }
  return out;
}
const train = days.slice(0, half).map(([d, l]) => [d, picks(l)]);
const test = days.slice(half).map(([d, l]) => [d, picks(l)]);
const flat = (ds) => ds.flatMap(([, l]) => l);
const stat = (l, nd) => {
  const n = l.length, w = l.filter((x) => x.won).length;
  const odd = n ? l.reduce((s, x) => s + x.odd, 0) / n : 0;
  return `${String(n).padStart(6)} paris | réussite ${(n ? (100 * w) / n : 0).toFixed(1).padStart(5)} % | cote moy ${odd.toFixed(2)} | ${(n / nd).toFixed(1).padStart(5)} par jour`;
};
const nTest = test.length;

console.log(`Jours : ${days.length} (réglage ${half}, contrôle ${nTest})\n`);
console.log('A) Paris simples et doubles chances, selon la probabilité du marché (2e moitié)');
for (const [a, b] of [[0.7, 0.8], [0.8, 0.85], [0.85, 0.9], [0.9, 0.93], [0.93, 0.95], [0.95, 0.97], [0.97, 1]]) {
  for (const single of [true, false]) {
    const l = flat(test).filter((x) => x.single === single && x.q >= a && x.q < b);
    if (l.length) console.log(`  ${single ? 'Victoire     ' : 'Double chance'} ${Math.round(a * 100)}-${Math.round(b * 100)} % : ${stat(l, nTest)}`);
  }
}

console.log('\nB) Les N paris les plus sûrs de chaque jour (1 par match), 2e moitié');
for (const N of [1, 3, 5, 10]) {
  for (const single of [true, false]) {
    const l = test.flatMap(([, ps]) => {
      const best = new Map();
      for (const x of ps.filter((x) => x.single === single)) if (!best.has(x.id) || best.get(x.id).q < x.q) best.set(x.id, x);
      return [...best.values()].sort((a, b) => b.q - a.q).slice(0, N);
    });
    console.log(`  Top ${String(N).padStart(2)} ${single ? 'victoires     ' : 'doubles chances'} : ${stat(l, nTest)}`);
  }
}

console.log('\nC) PrimaTips apporte-t-il quelque chose ? (marché ≥ 80 %, 2e moitié)');
const hi = flat(test).filter((x) => x.q >= 0.8 && x.ps != null);
console.log(`  PrimaTips d'accord     : ${stat(hi.filter((x) => x.agree), nTest)}`);
console.log(`  PrimaTips pas d'accord : ${stat(hi.filter((x) => !x.agree), nTest)}`);
const gaps = flat(train).filter((x) => x.q >= 0.8 && x.ps != null).map((x) => x.ps - x.q).sort((a, b) => a - b);
const g1 = gaps[Math.floor(gaps.length / 3)], g2 = gaps[Math.floor((2 * gaps.length) / 3)];
console.log(`  PrimaTips plus prudent que le marché   : ${stat(hi.filter((x) => x.ps - x.q < g1), nTest)}`);
console.log(`  PrimaTips ≈ marché                     : ${stat(hi.filter((x) => x.ps - x.q >= g1 && x.ps - x.q < g2), nTest)}`);
console.log(`  PrimaTips plus confiant que le marché  : ${stat(hi.filter((x) => x.ps - x.q >= g2), nTest)}`);

console.log('\nD) Championnats « fiables » choisis sur la 1re moitié, vérifiés sur la 2e (marché ≥ 80 %)');
const byLg = new Map();
for (const x of flat(train).filter((x) => x.q >= 0.8)) {
  const v = byLg.get(x.lg) || [0, 0, 0];
  v[0]++; v[1] += x.won ? 1 : 0; v[2] += x.q;
  byLg.set(x.lg, v);
}
const good = new Set([...byLg].filter(([, v]) => v[0] >= 25 && v[1] / v[0] > v[2] / v[0] + 0.03).map(([k]) => k));
const bad = new Set([...byLg].filter(([, v]) => v[0] >= 25 && v[1] / v[0] < v[2] / v[0] - 0.03).map(([k]) => k));
const t80 = flat(test).filter((x) => x.q >= 0.8);
console.log(`  ${good.size} championnats « au-dessus » : ${stat(t80.filter((x) => good.has(x.lg)), nTest)}`);
console.log(`  ${bad.size} championnats « en dessous »  : ${stat(t80.filter((x) => bad.has(x.lg)), nTest)}`);
console.log(`  Tous les autres            : ${stat(t80.filter((x) => !good.has(x.lg) && !bad.has(x.lg)), nTest)}`);

console.log('\nE) Meilleure combinaison trouvée sur la 1re moitié, vérifiée sur la 2e');
let best = null;
for (const qmin of [0.8, 0.85, 0.88, 0.9, 0.92, 0.94]) for (const ag of [false, true]) for (const lgf of [false, true]) {
  const f = (x) => x.q >= qmin && (!ag || x.agree) && (!lgf || !bad.has(x.lg));
  const l = flat(train).filter(f);
  if (l.length / half < 3) continue; // au moins 3 paris par jour
  const hit = l.filter((x) => x.won).length / l.length;
  if (!best || hit > best.hit) best = { qmin, ag, lgf, hit, f };
}
if (best) {
  console.log(`  Règle : marché ≥ ${Math.round(best.qmin * 100)} %${best.ag ? ' + PrimaTips d\'accord' : ''}${best.lgf ? ' + sans les championnats « en dessous »' : ''}`);
  console.log(`  1re moitié : réussite ${(100 * best.hit).toFixed(1)} %`);
  console.log(`  2e moitié  : ${stat(flat(test).filter(best.f), nTest)}`);
}

console.log('\nF) Coup sûr : les 10 paris les plus sûrs du jour avec une cote minimale (1 par match), 2e moitié');
for (const cmin of [1.15, 1.2, 1.25, 1.3]) {
  for (const kind of ['tous', 'victoires', 'doubles chances']) {
    const l = test.flatMap(([, ps]) => {
      const best = new Map();
      for (const x of ps) {
        if (x.odd < cmin) continue;
        if (kind === 'victoires' && !x.single) continue;
        if (kind === 'doubles chances' && x.single) continue;
        if (!best.has(x.id) || best.get(x.id).q < x.q) best.set(x.id, x);
      }
      return [...best.values()].sort((a, b) => b.q - a.q).slice(0, 10);
    });
    console.log(`  cote ≥ ${cmin.toFixed(2)} · ${kind.padEnd(15)} : ${stat(l, nTest)}`);
  }
}
// Répartition jour par jour pour la règle demandée (cote ≥ 1,20, tous types)
const dist = new Map();
for (const [, ps] of test) {
  const best = new Map();
  for (const x of ps) if (x.odd >= 1.2 && (!best.has(x.id) || best.get(x.id).q < x.q)) best.set(x.id, x);
  const top = [...best.values()].sort((a, b) => b.q - a.q).slice(0, 10);
  if (top.length < 10) continue;
  const w = top.filter((x) => x.won).length;
  dist.set(w, (dist.get(w) || 0) + 1);
}
const totalDays = [...dist.values()].reduce((a, b) => a + b, 0);
console.log(`\n  Règle « 10 matchs, cote ≥ 1,20 » : nombre de jours selon les matchs gagnés sur 10 (${totalDays} jours)`);
for (let w = 10; w >= 0; w--) if (dist.get(w)) console.log(`    ${String(w).padStart(2)}/10 : ${String(dist.get(w)).padStart(3)} jours (${((100 * dist.get(w)) / totalDays).toFixed(0)} %)`);
