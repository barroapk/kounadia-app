// Moteurs de coupons : l'ancien (copie exacte de l'app) et le nouveau (testé ici avant d'aller dans l'app).

export const PRESETS = {
  // Réglages actuels de l'app
  old: {
    prudent: { totalMin: 1.8, totalMax: 3, countMin: 2, countMax: 3, oddMin: 1.15, oddMax: 1.8, probMin: 65, probMax: 95, win: true, draw: false, dc: true },
    equilibre: { totalMin: 4, totalMax: 8, countMin: 3, countMax: 5, oddMin: 1.3, oddMax: 2.2, probMin: 55, probMax: 90, win: true, draw: false, dc: true },
    audacieux: { totalMin: 15, totalMax: 30, countMin: 5, countMax: 8, oddMin: 1.5, oddMax: 3.0, probMin: 40, probMax: 85, win: true, draw: true, dc: true },
  },
  // Réglages proposés : cotes plus réalistes, moins de matchs
  next: {
    prudent: { totalMin: 1.5, totalMax: 2.5, countMin: 2, countMax: 3, oddMin: 1.1, oddMax: 1.7, probMin: 70, probMax: 95, win: true, draw: false, dc: true },
    equilibre: { totalMin: 2.5, totalMax: 5, countMin: 2, countMax: 4, oddMin: 1.25, oddMax: 2.2, probMin: 58, probMax: 95, win: true, draw: false, dc: true },
    audacieux: { totalMin: 6, totalMax: 15, countMin: 3, countMax: 6, oddMin: 1.4, oddMax: 3.2, probMin: 40, probMax: 95, win: true, draw: true, dc: true },
  },
};

export function evalPick(pick, h, a) {
  switch (pick) {
    case '1': return h > a;
    case 'X': return h === a;
    case '2': return a > h;
    case '1X': return h >= a;
    case 'X2': return a >= h;
    case '12': return h !== a;
  }
  return false;
}

// Générateur pseudo-aléatoire reproductible (pour l'ancien moteur)
export function rng(seed) {
  let s = seed >>> 0;
  return {
    nextDouble() {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
    nextInt(n) {
      return Math.floor(this.nextDouble() * n);
    },
  };
}

const okOdds = (o) => Array.isArray(o) && o.length === 3 && o.every((x) => Number.isFinite(x) && x > 1.01);
const okProbs = (p) => Array.isArray(p) && p.length === 3 && p.every((x) => Number.isFinite(x));

// ---------- Ancien moteur (copie de coupon_engine.dart, marchés 1X2 + double chance) ----------
export function oldCandidates(matches, c) {
  const out = [];
  for (const m of matches) {
    const ev = [];
    const p = m.p, o = m.o;
    if (okProbs(p) && okOdds(o)) {
      if (c.win) {
        ev.push({ id: m.id, pick: '1', odd: o[0], prob: p[0] });
        ev.push({ id: m.id, pick: '2', odd: o[2], prob: p[2] });
      }
      if (c.draw) ev.push({ id: m.id, pick: 'X', odd: o[1], prob: p[1] });
      if (c.dc && Number.isFinite(m.to)) {
        const t = String(m.t || '').toUpperCase();
        const pr = t === '1X' ? p[0] + p[1] : t === 'X2' ? p[1] + p[2] : t === '12' ? p[0] + p[2] : null;
        if (pr != null) ev.push({ id: m.id, pick: t, odd: m.to, prob: pr });
      }
    }
    const ok = ev.filter((l) => l.odd > 1.01 && l.odd >= c.oddMin && l.odd <= c.oddMax && l.prob >= c.probMin && l.prob <= c.probMax);
    if (ok.length) out.push(ok);
  }
  return out;
}

function oldPick(evs, r) {
  if (evs.length === 1) return evs[0];
  const total = evs.reduce((s, l) => s + l.prob, 0);
  let x = r.nextInt(total < 1 ? 1 : total);
  for (const l of evs) {
    x -= l.prob;
    if (x < 0) return l;
  }
  return evs[evs.length - 1];
}

const sig = (legs) => legs.map((l) => `${l.id}:${l.pick}`).sort().join('|');

export function oldGenerate(cands, c, seed, max = 5) {
  if (cands.length < c.countMin) return [];
  const r = rng(seed);
  const found = new Map();
  for (let attempt = 0; attempt < 8000 && found.size < 300; attempt++) {
    const keyed = cands
      .map((e) => [e, Math.max(...e.map((l) => l.prob)) * (0.35 + r.nextDouble())])
      .sort((a, b) => b[1] - a[1]);
    const legs = [];
    let total = 1;
    for (const [evs] of keyed) {
      if (legs.length >= c.countMax) break;
      const l = oldPick(evs, r);
      const nt = total * l.odd;
      if (nt > c.totalMax) continue;
      legs.push(l);
      total = nt;
      if (legs.length >= c.countMin && total >= c.totalMin) break;
    }
    if (legs.length < c.countMin || legs.length > c.countMax) continue;
    if (total < c.totalMin || total > c.totalMax) continue;
    found.set(sig(legs), { legs, total, prob: legs.reduce((v, l) => v * l.prob / 100, 1) });
  }
  return diversify([...found.values()].sort((a, b) => b.prob - a.prob), max);
}

function diversify(sorted, max) {
  const picked = [];
  const used = new Map();
  for (const cp of sorted) {
    if (picked.length >= max) break;
    if (cp.legs.some((l) => (used.get(l.id) || 0) >= 2)) continue;
    picked.push(cp);
    for (const l of cp.legs) used.set(l.id, (used.get(l.id) || 0) + 1);
  }
  return picked;
}

// ---------- Nouveau moteur (même calcul, ligne par ligne, que coupon_engine.dart) ----------
// 1) Probabilité = cotes des bookmakers, marge retirée (le backtest montre qu'elle est la mieux calibrée).
// 2) Chaque pari est noté par son « coût » : -ln(P) / ln(cote). Plus il est bas, mieux le risque est payé.
// 3) Recherche en faisceau des combinaisons à la plus forte probabilité dans la fourchette de cote.
export const DEFAULT_TUNE = { w: 0, vmin: 0.9, dcCut: 0.98 };

const cmpStr = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const costOf = (l) => -Math.log(l.prob / 100) / Math.log(l.odd);

export function newLegs(m, c, tune) {
  const p = m.p, o = m.o;
  if (!okOdds(o)) return [];
  const inv = o.map((x) => 1 / x);
  const s = inv[0] + inv[1] + inv[2];
  let q = inv.map((x) => x / s);
  if (tune.w > 0 && okProbs(p)) {
    const sp = p[0] + p[1] + p[2];
    if (sp > 50) q = q.map((x, i) => tune.w * (p[i] / sp) + (1 - tune.w) * x);
  }
  const dcOdd = (i, j, code) => {
    if (String(m.t || '').toUpperCase() === code && Number.isFinite(m.to) && m.to > 1.01) return m.to;
    return Math.round((tune.dcCut / (inv[i] + inv[j])) * 100) / 100;
  };
  const ev = [];
  const add = (pick, odd, P) => {
    if (odd > 1.01 && P > 0 && P < 1) ev.push({ id: m.id, pick, odd, prob: Math.round(P * 100), P });
  };
  if (c.win) {
    add('1', o[0], q[0]);
    add('2', o[2], q[2]);
  }
  if (c.draw) add('X', o[1], q[1]);
  if (c.dc) {
    add('1X', dcOdd(0, 1, '1X'), q[0] + q[1]);
    add('X2', dcOdd(1, 2, 'X2'), q[1] + q[2]);
    add('12', dcOdd(0, 2, '12'), q[0] + q[2]);
  }
  return ev
    .filter((l) => l.odd >= c.oddMin && l.odd <= c.oddMax && l.prob >= c.probMin && l.prob <= c.probMax && l.P * l.odd >= tune.vmin)
    .map(({ id, pick, odd, prob }) => ({ id, pick, odd, prob }))
    .sort((a, b) => costOf(a) - costOf(b) || cmpStr(a.pick, b.pick));
}

export function newCandidates(matches, c, tune = DEFAULT_TUNE) {
  const out = [];
  for (const m of matches) {
    const legs = newLegs(m, c, tune);
    if (legs.length) out.push(legs);
  }
  return out;
}

const sigOf = (legs) => legs.map((l) => `${l.id}:${l.pick}`).sort().join('|');

export function newSearch(cands, c, exclude = new Set(), max = 5) {
  if (cands.length < c.countMin) return [];
  const pool = [];
  for (const e of cands) e.forEach((l, i) => pool.push({ l, rank: i, cost: costOf(l) }));
  pool.sort((a, b) => a.rank - b.rank || a.cost - b.cost || a.l.id - b.l.id || cmpStr(a.l.pick, b.l.pick));
  const top = pool.slice(0, 40).map((x) => x.l);
  let beam = [{ legs: [], total: 1, lp: 0, last: -1 }];
  const done = new Map();
  const key = (s) => s.lp / Math.max(Math.log(s.total), 0.01);
  for (let depth = 0; depth < c.countMax && beam.length; depth++) {
    const next = [];
    for (const st of beam) {
      for (let i = st.last + 1; i < top.length; i++) {
        const l = top[i];
        if (st.legs.some((x) => x.id === l.id)) continue;
        const total = st.total * l.odd;
        if (total > c.totalMax) continue;
        const ns = { legs: [...st.legs, l], total, lp: st.lp + Math.log(l.prob / 100), last: i };
        if (ns.legs.length >= c.countMin && total >= c.totalMin) {
          const sg = sigOf(ns.legs);
          if (!exclude.has(sg)) done.set(sg, ns);
        } else next.push(ns);
      }
    }
    next.sort((a, b) => key(b) - key(a) || b.lp - a.lp || cmpStr(sigOf(a.legs), sigOf(b.legs)));
    beam = next.slice(0, 300);
  }
  const sorted = [...done.entries()]
    .map(([sg, s]) => ({ sg, legs: s.legs, total: s.total, prob: s.legs.reduce((v, l) => v * l.prob / 100, 1) }))
    .sort((a, b) => b.prob - a.prob || cmpStr(a.sg, b.sg));
  return diversify(sorted, max);
}

export const newGenerate = (matches, c, tune = DEFAULT_TUNE, max = 5) => newSearch(newCandidates(matches, c, tune), c, new Set(), max);
