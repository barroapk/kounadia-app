// KOUNADIA · robot de notifications en direct (Cloudflare Worker + Durable Object).
// Toutes les 3 s pendant les matchs : lit le direct PrimaTips, détecte buts / coup d'envoi /
// mi-temps / fin, et envoie la notification Firebase aux abonnés du championnat ou du match.

const LIVE_URL = 'https://primatips.com/liveresults?day=0';
const UA = { 'User-Agent': 'KOUNADIA-App/1.0' };
const FAST = 3000; // matchs en cours
const SLOW = 20000; // aucun match en cours
const LANGS = ['fr', 'en', 'pt', 'es', 'ar'];
const MAX_EVENTS_PER_TICK = 8; // 5 envois par événement : reste sous la limite d'appels

const KFEED = 'https://raw.githubusercontent.com/barroapk/kfeed';

// Pronostics et coupons
const TIP = {
  fr: { sure: '🎯 Coup sûr du jour', sureB: '{n} sélections bien analysées vous attendent', pro: '🔮 Pronostics du jour', proB: 'Kounadia IA et Expert : {n} matchs analysés', win: '✅ Coup sûr gagné', cw: '🎉 Coupon gagné !', cwB: '{n}/{n} matchs gagnés · cote {odd}', cl: '❌ Coupon perdu', clB: '{m} a fait échouer votre coupon' },
  en: { sure: '🎯 Sure bet of the day', sureB: '{n} carefully analysed picks are waiting for you', pro: '🔮 Today\'s predictions', proB: 'Kounadia AI and Expert: {n} matches analysed', win: '✅ Sure bet won', cw: '🎉 Bet slip won!', cwB: '{n}/{n} matches won · odds {odd}', cl: '❌ Bet slip lost', clB: '{m} broke your bet slip' },
  pt: { sure: '🎯 Aposta segura do dia', sureB: '{n} seleções bem analisadas esperam por si', pro: '🔮 Previsões do dia', proB: 'Kounadia IA e Expert: {n} jogos analisados', win: '✅ Aposta segura ganha', cw: '🎉 Cupom ganho!', cwB: '{n}/{n} jogos ganhos · odd {odd}', cl: '❌ Cupom perdido', clB: '{m} fez falhar o seu cupom' },
  es: { sure: '🎯 Apuesta segura del día', sureB: '{n} selecciones bien analizadas te esperan', pro: '🔮 Pronósticos del día', proB: 'Kounadia IA y Experto: {n} partidos analizados', win: '✅ Apuesta segura ganada', cw: '🎉 ¡Cupón ganado!', cwB: '{n}/{n} partidos ganados · cuota {odd}', cl: '❌ Cupón perdido', clB: '{m} hizo fallar tu cupón' },
  ar: { sure: '🎯 الرهان الآمن لليوم', sureB: '{n} اختيارات مدروسة بعناية بانتظارك', pro: '🔮 توقعات اليوم', proB: 'KOUNADIA AI والخبير: {n} مباراة محللة', win: '✅ ربح الرهان الآمن', cw: '🎉 ربحت القسيمة!', cwB: '{n}/{n} مباريات رابحة · الاحتمال {odd}', cl: '❌ خسرت القسيمة', clB: '{m} أفشلت قسيمتك' },
};
const fill = (t, v) => t.replace(/\{(\w+)\}/g, (_, k) => (v[k] ?? ''));

// Même règle que l'app (CouponEngine.evalPick).
function evalPick(pick, h, a) {
  switch (pick) {
    case '1': return h > a;
    case 'X': return h === a;
    case '2': return a > h;
    case '1X': return h >= a;
    case 'X2': return a >= h;
    case '12': return h !== a;
    case 'BTS': return h > 0 && a > 0;
    case 'OTS': return h === 0 || a === 0;
  }
  const g = /^([OU])(\d)(\d)$/.exec(pick);
  if (g) {
    const line = Number(g[2]) + Number(g[3]) / 10;
    return g[1] === 'O' ? h + a > line : h + a < line;
  }
  return false;
}

const TXT = {
  fr: { goal: '⚽ BUT ! {team}', ko: "▶️ Coup d'envoi", ht: '⏸️ Mi-temps', ft: '🏁 Fin du match' },
  en: { goal: '⚽ GOAL! {team}', ko: '▶️ Kick-off', ht: '⏸️ Half-time', ft: '🏁 Full-time' },
  pt: { goal: '⚽ GOLO! {team}', ko: '▶️ Início do jogo', ht: '⏸️ Intervalo', ft: '🏁 Fim do jogo' },
  es: { goal: '⚽ ¡GOL! {team}', ko: '▶️ Comienza el partido', ht: '⏸️ Descanso', ft: '🏁 Final del partido' },
  ar: { goal: '⚽ هدف! {team}', ko: '▶️ انطلاق المباراة', ht: '⏸️ نهاية الشوط الأول', ft: '🏁 نهاية المباراة' },
};

// Même calcul que l'app (FNV-1a 32 bits).
function leagueHash(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

const b64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const b64url = (u8) => btoa(String.fromCharCode(...u8)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const enc = (s) => new TextEncoder().encode(s);

const isFin = (st) => /^(FT|AET|PEN|AP)/i.test(st);
const isHT = (st) => /^HT$/i.test(st);
const inPlay = (st) => /^\d/.test(st) || isHT(st);

export class Poller {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.names = null; // id -> [home, away, leagueLabel]
    this.namesAt = 0;
    this.token = null;
    this.tokenExp = 0;
  }

  // /live : direct en temps réel (WebSocket) · /log?ids=1,2 : événements des matchs
  // Tout appel (dont la relance de chaque minute) s'assure que la boucle tourne.
  async fetch(req) {
    const a = await this.state.storage.getAlarm();
    if (a == null || a < Date.now() - 30000) await this.state.storage.setAlarm(Date.now() + 1000);
    const url = new URL(req.url);
    if (url.pathname === '/live' && req.headers.get('Upgrade') === 'websocket') {
      const [client, server] = Object.values(new WebSocketPair());
      this.state.acceptWebSocket(server);
      const live = (await this.state.storage.get('live')) || {};
      server.send(JSON.stringify({ k: 'snap', live }));
      return new Response(null, { status: 101, webSocket: client });
    }
    if (url.pathname === '/tr' && req.method === 'POST') return this.translate(req);
    if (url.pathname === '/coupons' && req.method === 'POST') return this.saveCoupons(req);
    if (url.pathname === '/log') {
      const ids = new Set((url.searchParams.get('ids') || '').split(',').filter(Boolean).slice(0, 300).map(Number));
      const log = ((await this.state.storage.get('log')) || []).filter((e) => ids.has(e.id));
      return Response.json(log, { headers: { 'access-control-allow-origin': '*', 'cache-control': 'no-store' } });
    }
    const stat = (await this.state.storage.get('stat')) || {};
    stat.clients = this.state.getWebSockets().length;
    stat.err = (await this.state.storage.get('err')) || null;
    stat.fcmErr = (await this.state.storage.get('fcmErr')) || null;
    stat.src = (await this.state.storage.get('src')) || null;
    const al = await this.state.storage.getAlarm();
    stat.nextTick = al ? new Date(al).toISOString() : null;
    return Response.json(stat);
  }

  // Traduction des publicités (texte écrit en français dans KND Tigui), gardée en mémoire.
  async translate(req) {
    const NAMES = { en: 'english', pt: 'portuguese', es: 'spanish', ar: 'arabic' };
    let body = {};
    try {
      body = await req.json();
    } catch (_) {}
    const to = NAMES[body.to];
    const texts = Array.isArray(body.texts) ? body.texts.slice(0, 40).map((t) => String(t).slice(0, 600)) : [];
    if (!to || !this.env.AI) return Response.json({ out: texts });
    const out = [];
    for (const t of texts) {
      if (!t.trim()) {
        out.push(t);
        continue;
      }
      const key = `tr:${body.to}:${leagueHash(t)}:${t.length}`;
      let v = await this.state.storage.get(key);
      if (v == null) {
        try {
          const r = await this.env.AI.run('@cf/meta/m2m100-1.2b', { text: t, source_lang: 'french', target_lang: to });
          v = (r && r.translated_text) || '';
          if (v) await this.state.storage.put(key, v);
        } catch (e) {
          await this.state.storage.put('trErr', `${new Date().toISOString()} ${e}`);
        }
      }
      out.push(v || t);
    }
    return Response.json({ out });
  }

  webSocketMessage(ws, msg) {
    if (msg === 'ping') ws.send('pong');
  }

  webSocketClose(ws, code) {
    try {
      ws.close(code, 'bye');
    } catch (_) {}
  }

  broadcast(obj) {
    const socks = this.state.getWebSockets();
    if (!socks.length) return;
    const msg = JSON.stringify(obj);
    for (const ws of socks) {
      try {
        ws.send(msg);
      } catch (_) {}
    }
  }

  async alarm() {
    let next = SLOW;
    try {
      next = await this.tick();
    } catch (e) {
      await this.state.storage.put('err', `${new Date().toISOString()} ${e}`);
    }
    await this.state.storage.setAlarm(Date.now() + next);
  }

  // ---------- Noms des équipes (flux KOUNADIA chiffré) ----------
  async loadNames(force) {
    if (!force && this.names && Date.now() - this.namesAt < 10 * 60000) return;
    if (force && Date.now() - this.namesAt < 60000) return; // pas plus d'une fois par minute
    this.namesAt = Date.now();
    const d = await this.feed('scores/scores.json');
    if (!d) return;
    const lists = d.days && typeof d.days === 'object' ? Object.values(d.days) : [d.matches || []];
    const names = {};
    for (const l of lists) {
      for (const m of l || []) {
        const c = (m.country || '').toString();
        const lg = (m.league || '').toString();
        names[m.id] = [String(m.home || ''), String(m.away || ''), c ? `${c} - ${lg}` : lg];
      }
    }
    this.names = names;
  }

  // Fichier du flux KOUNADIA (chiffré), ou null.
  async feed(path) {
    const r = await fetch(`${KFEED}/${path}?v=${Math.floor(Date.now() / 60000)}`);
    if (!r.ok) return null;
    let text = (await r.text()).trim();
    if (text.startsWith('KD1.')) {
      const raw = b64(text.slice(4));
      const key = await crypto.subtle.importKey('raw', b64(this.env.KD_KEY), 'AES-GCM', false, ['decrypt']);
      const z = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: raw.slice(0, 12), tagLength: 128 }, key, raw.slice(12));
      const ds = new Blob([z]).stream().pipeThrough(new DecompressionStream('gzip'));
      text = await new Response(ds).text();
    }
    return JSON.parse(text);
  }

  // ---------- Pronostics : nouveaux Coup sûr / pronostics, Coup sûr gagnés ----------
  async checkTips() {
    if (Date.now() - (this.tipsAt || 0) < 5 * 60000) return;
    this.tipsAt = Date.now();
    const st = (await this.state.storage.get('tips')) || {};
    const first = !st.init;
    const today = new Date().toISOString().slice(0, 10);
    const jobs = [];
    try {
      const vip = await this.feed('vip/vip.json');
      const singles = Array.isArray(vip?.singles) ? vip.singles : [];
      if (vip?.date && singles.length && st.vipDate !== vip.date) {
        st.vipDate = vip.date;
        st.singles = singles.map((l) => ({ id: Number(l.id), pick: String(l.pick), home: String(l.home), away: String(l.away) }));
        st.won = [];
        if (!first) for (const lang of LANGS) jobs.push(['tips', lang, TIP[lang].sure, fill(TIP[lang].sureB, { n: singles.length }), { t: 'sure' }, 'sure']);
      }
    } catch (_) {}
    try {
      const pr = await this.feed('pronos/today.json');
      const isToday = (e) => {
        const d = new Date(e?.date || '');
        return !isNaN(d) && d.toISOString().slice(0, 10) === today;
      };
      const n = [...(pr?.ia || []), ...(pr?.expert || [])].filter(isToday).length;
      if (n > 0 && st.proDate !== today) {
        st.proDate = today;
        if (!first) for (const lang of LANGS) jobs.push(['tips', lang, TIP[lang].pro, fill(TIP[lang].proB, { n }), { t: 'pro' }, 'pro']);
      }
    } catch (_) {}
    st.init = true;
    await this.state.storage.put('tips', st);
    await this.sendJobs(jobs);
  }

  // ---------- Coupons des utilisateurs : gagné / perdu ----------
  async saveCoupons(req) {
    let b = {};
    try {
      b = await req.json();
    } catch (_) {}
    const token = String(b.token || '');
    if (token.length < 20) return Response.json({ ok: false }, { status: 400 });
    const key = `cp:${leagueHash(token)}${leagueHash(token.split('').reverse().join(''))}`;
    const old = (await this.state.storage.get(key))?.coupons || [];
    const done = new Set(old.filter((c) => c.done).map((c) => c.sig));
    const coupons = (Array.isArray(b.coupons) ? b.coupons : []).slice(0, 5).map((c) => ({
      sig: String(c.sig || ''),
      odd: String(c.odd || ''),
      legs: (Array.isArray(c.legs) ? c.legs : []).slice(0, 30).map((l) => ({ id: Number(l.id), pick: String(l.pick), home: String(l.home || ''), away: String(l.away || '') })),
      done: done.has(String(c.sig || '')),
    }));
    if (!coupons.length) await this.state.storage.delete(key);
    else await this.state.storage.put(key, { token, lang: LANGS.includes(b.lang) ? b.lang : 'en', coupons, at: Date.now() });
    return Response.json({ ok: true });
  }

  async checkCoupons(fin) {
    // fin : matchs terminés à ce passage -> score final
    const ids = Object.keys(fin);
    if (!ids.length) return;
    const finals = (await this.state.storage.get('finals')) || {};
    const now = Date.now();
    for (const id of ids) finals[id] = [...fin[id], now];
    for (const k of Object.keys(finals)) if (now - finals[k][2] > 48 * 3600000) delete finals[k];
    await this.state.storage.put('finals', finals);

    const jobs = [];
    // Coup sûr gagnés
    const st = (await this.state.storage.get('tips')) || {};
    if (st.singles?.length) {
      st.won = st.won || [];
      for (const l of st.singles) {
        const f = fin[l.id];
        if (f && f[0] != null && evalPick(l.pick, f[0], f[1]) && !st.won.includes(l.id)) {
          st.won.push(l.id);
          for (const lang of LANGS) jobs.push(['tips', lang, TIP[lang].win, `${l.home} ${f[0]}-${f[1]} ${l.away}`, { t: 'sure', id: String(l.id) }, `s${l.id}`]);
        }
      }
      await this.state.storage.put('tips', st);
    }
    // Coupons des utilisateurs
    const all = await this.state.storage.list({ prefix: 'cp:' });
    for (const [key, u] of all) {
      let changed = false;
      for (const c of u.coupons) {
        if (c.done || !c.legs.some((l) => fin[l.id])) continue;
        const res = c.legs.map((l) => {
          const f = finals[l.id];
          return f && f[0] != null ? evalPick(l.pick, f[0], f[1]) : null;
        });
        const t = TIP[u.lang] || TIP.en;
        const lost = c.legs.findIndex((l, i) => res[i] === false);
        if (lost >= 0) {
          const l = c.legs[lost];
          jobs.push(['token', u.token, t.cl, fill(t.clB, { m: `${l.home} - ${l.away}` }), { t: 'coupon' }, `c${c.sig.slice(0, 20)}`]);
          c.done = changed = true;
        } else if (res.every((x) => x === true)) {
          jobs.push(['token', u.token, t.cw, fill(t.cwB, { n: c.legs.length, odd: c.odd }), { t: 'coupon' }, `c${c.sig.slice(0, 20)}`]);
          c.done = changed = true;
        }
      }
      if (changed) await this.state.storage.put(key, u);
    }
    await this.sendJobs(jobs);
  }

  // Envoi groupé : [type ('tips' | 'token'), cible (langue ou jeton), titre, texte, data, tag]
  async sendJobs(jobs) {
    if (!jobs.length) return;
    const token = await this.oauth();
    await Promise.allSettled(
      jobs.slice(0, 40).map(([kind, target, title, body, data, tag]) => {
        const where = kind === 'tips' ? { topic: `${target}_tips` } : { token: target };
        return this.fcm(token, { ...where, notification: { title, body }, data, android: { priority: 'HIGH', ttl: '3600s', notification: { channel_id: 'live', tag, sound: 'default' } } });
      }),
    );
  }

  async fcm(token, message) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${this.sa().project_id}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message }),
    });
    if (!r.ok) {
      const t = await r.text();
      await this.state.storage.put('fcmErr', `${r.status} ${t.slice(0, 300)}`);
      if (r.status === 401) this.tokenExp = 0;
      // Téléphone désinstallé : on oublie ses coupons.
      if (message.token && (r.status === 404 || t.includes('UNREGISTERED'))) {
        const key = `cp:${leagueHash(message.token)}${leagueHash(message.token.split('').reverse().join(''))}`;
        await this.state.storage.delete(key);
      }
    }
    return r.ok;
  }

  // ---------- Boucle principale ----------
  async tick() {
    const r = await fetch(`${LIVE_URL}&_=${Date.now()}`, { headers: UA, cf: { cacheTtl: 0 } });
    const body = await r.text();
    let list = null;
    try {
      list = JSON.parse(body);
    } catch (_) {}
    if (!r.ok || !Array.isArray(list)) {
      await this.state.storage.put('src', `${new Date().toISOString()} HTTP ${r.status} ${body.slice(0, 160)}`);
      return SLOW;
    }
    await this.state.storage.put('src', `ok ${list.length}`);

    // État précédent ; trop ancien (robot relancé après une pause) = on repart sans notifier.
    const liveAt = (await this.state.storage.get('liveAt')) || 0;
    const prev = Date.now() - liveAt < 120000 ? await this.state.storage.get('live') : null; // id -> [hs, as, st]
    const cur = {};
    const events = (await this.state.storage.get('queue')) || [];
    const fresh = []; // événements détectés à ce passage (historique + direct)
    const changed = {};
    let live = 0;
    await this.loadNames(false);

    for (const l of list) {
      const id = Number(l.id);
      if (!id) continue;
      const st = String(l.st ?? '').trim();
      const hs = Number.isFinite(l.hs) ? l.hs : l.hs == null ? null : Number(l.hs);
      const as = Number.isFinite(l.as) ? l.as : l.as == null ? null : Number(l.as);
      cur[id] = [hs, as, st];
      if (inPlay(st)) live++;
      const q = prev?.[id];
      if (!q || q[0] !== hs || q[1] !== as || q[2] !== st) changed[id] = cur[id];
      if (!prev) continue; // premier passage : on mémorise sans notifier
      const p = prev[id];
      const pst = p ? p[2] : '';
      const base = { id, hs, as, st };
      const started = /^\d/.test(st) && (p ? !inPlay(pst) && !isFin(pst) : parseInt(st, 10) <= 3);
      if (started) fresh.push({ ...base, t: 'ko' });
      if (p && hs != null && as != null && p[0] != null && p[1] != null && (hs > p[0] || as > p[1])) {
        fresh.push({ ...base, t: 'goal', side: hs > p[0] ? 'h' : 'a' });
      }
      if (isHT(st) && !isHT(pst)) fresh.push({ ...base, t: 'ht' });
      if (isFin(st) && p && !isFin(pst)) fresh.push({ ...base, t: 'ft' });
    }
    await this.state.storage.put('live', cur);
    await this.state.storage.put('liveAt', Date.now());

    // Direct dans l'app : seulement ce qui a changé, dès maintenant.
    const at = Date.now();
    for (const e of fresh) e.at = at;
    if (Object.keys(changed).length || fresh.length) this.broadcast({ k: 'diff', live: changed, ev: fresh });
    if (fresh.length) {
      const old = (await this.state.storage.get('log')) || [];
      const log = old.filter((e) => at - e.at < 36 * 3600000).concat(fresh).slice(-5000);
      await this.state.storage.put('log', log);
    }
    events.push(...fresh);

    // Pronostics (toutes les 5 min) et coupons (à chaque fin de match)
    const fin = {};
    for (const e of fresh) if (e.t === 'ft') fin[e.id] = [e.hs, e.as];
    try {
      await this.checkCoupons(fin);
      await this.checkTips();
    } catch (e) {
      await this.state.storage.put('err', `${new Date().toISOString()} tips ${e}`);
    }

    // Les buts d'abord ; le reste attend le passage suivant (3 s) si trop d'événements.
    events.sort((a, b) => (a.t === 'goal' ? 0 : 1) - (b.t === 'goal' ? 0 : 1));
    const now = events.slice(0, MAX_EVENTS_PER_TICK);
    const later = events.slice(MAX_EVENTS_PER_TICK).slice(0, 200);
    let sent = 0;
    if (now.length) {
      if (now.some((e) => !this.names?.[e.id])) await this.loadNames(true);
      const token = await this.oauth();
      const jobs = [];
      for (const e of now) {
        const n = this.names?.[e.id];
        if (!n) continue; // match inconnu du flux : pas de nom à afficher
        for (const lang of LANGS) jobs.push(this.send(token, lang, e, n));
      }
      const res = await Promise.allSettled(jobs);
      sent = res.filter((x) => x.status === 'fulfilled' && x.value).length;
    }
    await this.state.storage.put('queue', later);
    const stat = (await this.state.storage.get('stat')) || { sent: 0 };
    stat.at = new Date().toISOString();
    stat.live = live;
    stat.sent = (stat.sent || 0) + sent;
    stat.queue = later.length;
    await this.state.storage.put('stat', stat);
    return live > 0 || later.length ? FAST : SLOW;
  }

  // ---------- Firebase ----------
  async send(token, lang, e, [home, away, league]) {
    const t = TXT[lang];
    const score = e.hs != null && e.as != null ? `${home} ${e.hs}-${e.as} ${away}` : `${home} - ${away}`;
    const min = /^\d/.test(e.st) ? ` (${e.st}')` : '';
    let title = t[e.t];
    let body = `${score}${e.t === 'goal' ? min : ''}`;
    if (e.t === 'goal') title = title.replace('{team}', e.side === 'h' ? home : away);
    body += `\n${league}`;
    const cond = `'${lang}_l_${leagueHash(league)}' in topics || '${lang}_m_${e.id}' in topics`;
    const msg = {
      message: {
        condition: cond,
        notification: { title, body },
        data: { id: String(e.id), t: e.t },
        android: {
          priority: 'HIGH',
          ttl: '600s',
          notification: { channel_id: 'live', tag: `m${e.id}`, sound: 'default' },
        },
      },
    };
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${this.sa().project_id}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(msg),
    });
    if (!r.ok) {
      await this.state.storage.put('fcmErr', `${r.status} ${(await r.text()).slice(0, 300)}`);
      if (r.status === 401) this.tokenExp = 0;
    }
    return r.ok;
  }

  sa() {
    return (this._sa ??= JSON.parse(this.env.FCM_SA));
  }

  async oauth() {
    if (this.token && Date.now() < this.tokenExp) return this.token;
    const sa = this.sa();
    const now = Math.floor(Date.now() / 1000);
    const head = b64url(enc(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
    const claim = b64url(
      enc(
        JSON.stringify({
          iss: sa.client_email,
          scope: 'https://www.googleapis.com/auth/firebase.messaging',
          aud: 'https://oauth2.googleapis.com/token',
          iat: now,
          exp: now + 3600,
        }),
      ),
    );
    const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
    const key = await crypto.subtle.importKey('pkcs8', b64(pem), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, [
      'sign',
    ]);
    const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc(`${head}.${claim}`)));
    const r = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${head}.${claim}.${b64url(sig)}`,
    });
    const j = await r.json();
    if (!j.access_token) throw new Error(`oauth ${r.status}`);
    this.token = j.access_token;
    this.tokenExp = Date.now() + 50 * 60000;
    return this.token;
  }
}

const poller = (env) => env.POLLER.get(env.POLLER.idFromName('main'));

export default {
  async scheduled(_ev, env, ctx) {
    ctx.waitUntil(poller(env).fetch('https://poller/kick'));
  },
  async fetch(req, env) {
    return poller(env).fetch(req);
  },
};
