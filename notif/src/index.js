// KOUNADIA · robot de notifications en direct (Cloudflare Worker + Durable Object).
// Toutes les 3 s pendant les matchs : lit le direct PrimaTips, détecte buts / coup d'envoi /
// mi-temps / fin, et envoie la notification Firebase aux abonnés du championnat ou du match.

const LIVE_URL = 'https://primatips.com/liveresults?day=0';
const UA = { 'User-Agent': 'KOUNADIA-App/1.0' };
const FAST = 3000; // matchs en cours
const SLOW = 20000; // aucun match en cours
const LANGS = ['fr', 'en', 'pt', 'es', 'ar'];
const SEND_BUDGET = 38; // envois Firebase par passage (Cloudflare autorise 50 appels au total)
const DIRECT_MAX = 120; // au-delà, on passe par les « sujets » Firebase (plus lents mais sans limite)
const OUTQ_MAX = 1500;
const TOPIC_RE = /^[a-z]{2}_(l2|m2)_[0-9a-z]{1,16}$/;

const KFEED = 'https://raw.githubusercontent.com/barroapk/kfeed';
// Tâches du dépôt kfeed relancées par le robot : [fichier, toutes les N minutes].
const KICKS = [['scores.yml', 15], ['vip.yml', 30], ['pronos.yml', 60]];

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

// Annonces courtes et vivantes, selon ce que change le but.
const TXT = {
  fr: { goal: '⚽ BUT ! {team}', open: '⚽ {team} ouvre le score !', equal: '⚖️ {team} égalise !', lead: "⚽ {team} reprend l'avantage !",
    comeback: '🔥 Renversant ! {team} passe devant', brk: '⚽ {team} fait le break !', more: '💥 {team} enfonce le clou !',
    reduce: "⚽ {team} réduit l'écart", late: "⏱️ But à la {min}' !", ko: "▶️ C'est parti !", ht: '⏸️ Mi-temps', ft: '🏁 Fin du match',
    win: "{team} s'impose", draw: 'Match nul' },
  en: { goal: '⚽ GOAL! {team}', open: '⚽ {team} open the scoring!', equal: '⚖️ {team} equalise!', lead: '⚽ {team} back in front!',
    comeback: '🔥 What a turnaround! {team} lead', brk: '⚽ {team} double the lead!', more: '💥 {team} pile on!',
    reduce: '⚽ {team} pull one back', late: "⏱️ Goal in the {min}'!", ko: '▶️ Kick-off!', ht: '⏸️ Half-time', ft: '🏁 Full-time',
    win: '{team} win', draw: 'Draw' },
  pt: { goal: '⚽ GOLO! {team}', open: '⚽ {team} abre o marcador!', equal: '⚖️ {team} empata!', lead: '⚽ {team} volta à frente!',
    comeback: '🔥 Reviravolta! {team} passa à frente', brk: '⚽ {team} amplia!', more: '💥 {team} não para!',
    reduce: '⚽ {team} reduz', late: "⏱️ Aos {min}'!", ko: '▶️ Começou!', ht: '⏸️ Intervalo', ft: '🏁 Fim do jogo',
    win: '{team} vence', draw: 'Empate' },
  es: { goal: '⚽ ¡GOL! {team}', open: '⚽ ¡{team} abre el marcador!', equal: '⚖️ ¡{team} empata!', lead: '⚽ ¡{team} vuelve a mandar!',
    comeback: '🔥 ¡Remontada! {team} se pone por delante', brk: '⚽ ¡{team} amplía la ventaja!', more: '💥 ¡{team} no perdona!',
    reduce: '⚽ {team} recorta distancias', late: "⏱️ ¡En el {min}'!", ko: '▶️ ¡Arranca el partido!', ht: '⏸️ Descanso', ft: '🏁 Final del partido',
    win: '{team} gana', draw: 'Empate' },
  ar: { goal: '⚽ هدف! {team}', open: '⚽ {team} يفتتح التسجيل!', equal: '⚖️ {team} يعادل!', lead: '⚽ {team} يتقدم من جديد!',
    comeback: '🔥 انقلاب مثير! {team} يتقدم', brk: '⚽ {team} يعزز تقدمه!', more: '💥 {team} يواصل التسجيل!',
    reduce: '⚽ {team} يقلص الفارق', late: "⏱️ في الدقيقة {min}!", ko: '▶️ انطلقت المباراة!', ht: '⏸️ نهاية الشوط الأول', ft: '🏁 نهاية المباراة',
    win: 'فوز {team}', draw: 'تعادل' },
};

// Ce que change le but : ouverture, égalisation, retour devant, renversement, break, réduction du score.
function goalKind(side, hs, as, trailed) {
  const own = side === 'h' ? hs : as;
  const opp = side === 'h' ? as : hs;
  if (own === opp) return 'equal';
  if (own < opp) return 'reduce';
  if (own - 1 === opp) return own + opp === 1 ? 'open' : trailed ? 'comeback' : 'lead';
  return own - opp === 2 ? 'brk' : 'more';
}

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
    // « ping » du téléphone : réponse automatique de Cloudflare, sans réveiller le robot
    // (gratuit et sans limite, même avec beaucoup d'utilisateurs connectés).
    try {
      state.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
    } catch (_) {}
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
    stat.kickErr = (await this.state.storage.get('kickErr')) || null;
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
    try {
      await this.kickJobs();
    } catch (_) {}
    await this.state.storage.setAlarm(Date.now() + next);
  }

  // GitHub lance très mal ses tâches planifiées (parfois toutes les 5 h au lieu de 30 min) :
  // le robot les relance lui-même à heure fixe (jeton limité aux « Actions » du dépôt kfeed).
  async kickJobs() {
    if (!this.env.GH_DISPATCH) return;
    const st = (await this.state.storage.get('kick')) || {};
    const now = Date.now();
    let changed = false;
    for (const [wf, min] of KICKS) {
      if (now - (st[wf] || 0) < min * 60000) continue;
      st[wf] = now;
      changed = true;
      try {
        const r = await fetch(`https://api.github.com/repos/barroapk/kfeed/actions/workflows/${wf}/dispatches`, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${this.env.GH_DISPATCH}`,
            accept: 'application/vnd.github+json',
            'user-agent': 'KOUNADIA-robot',
            'content-type': 'application/json',
          },
          body: JSON.stringify({ ref: 'main' }),
        });
        if (r.status !== 204) await this.state.storage.put('kickErr', `${new Date().toISOString()} ${wf} HTTP ${r.status}`);
      } catch (e) {
        await this.state.storage.put('kickErr', `${new Date().toISOString()} ${wf} ${e}`);
      }
    }
    if (changed) await this.state.storage.put('kick', st);
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
    return JSON.parse(await openFeed(await r.text(), this.env));
  }

  // Fichier Premium (« _p », clé Premium) ; sinon l'ancien fichier, s'il n'est pas l'invitation à mettre à jour.
  async premiumFeed(path) {
    const p = await this.feed(path.replace(/\.json$/, '_p.json')).catch(() => null);
    if (p) return p;
    const old = await this.feed(path);
    return old?.upgrade ? null : old;
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
      const vip = await this.premiumFeed('vip/vip.json');
      const singles = Array.isArray(vip?.singles) ? vip.singles : [];
      if (vip?.date && singles.length && st.vipDate !== vip.date) {
        st.vipDate = vip.date;
        st.singles = singles.map((l) => ({ id: Number(l.id), pick: String(l.pick), home: String(l.home), away: String(l.away) }));
        st.won = [];
        if (!first) for (const lang of LANGS) jobs.push(['tips', lang, TIP[lang].sure, fill(TIP[lang].sureB, { n: singles.length }), { t: 'sure' }, 'sure']);
      }
    } catch (_) {}
    try {
      const pr = await this.premiumFeed('pronos/today.json');
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

  // ---------- Téléphones : coupons en cours + matchs/championnats suivis ----------
  devKey(token) {
    return `cp:${leagueHash(token)}${leagueHash(token.split('').reverse().join(''))}`;
  }

  async saveCoupons(req) {
    let b = {};
    try {
      b = await req.json();
    } catch (_) {}
    const token = String(b.token || '');
    // Seuls de vrais jetons Firebase sont acceptés (évite de remplir le robot de faux appareils).
    if (token.length < 100 || token.length > 4096 || !/^[A-Za-z0-9:_-]+$/.test(token)) {
      return Response.json({ ok: false }, { status: 400 });
    }
    const key = this.devKey(token);
    const prev = (await this.state.storage.get(key)) || null;
    const done = new Set((prev?.coupons || []).filter((c) => c.done).map((c) => c.sig));
    const coupons = (Array.isArray(b.coupons) ? b.coupons : []).slice(0, 5).map((c) => ({
      sig: String(c.sig || ''),
      odd: String(c.odd || ''),
      legs: (Array.isArray(c.legs) ? c.legs : []).slice(0, 30).map((l) => ({ id: Number(l.id), pick: String(l.pick), home: String(l.home || ''), away: String(l.away || '') })),
      done: done.has(String(c.sig || '')),
    }));
    // Sujets suivis (nouvelle version de l'app) : notifications envoyées directement au téléphone.
    const topics = [...new Set((Array.isArray(b.topics) ? b.topics : []).map(String).filter((t) => TOPIC_RE.test(t)))].slice(0, 300);
    await this.reindex(key, prev?.topics || [], topics);
    if (!coupons.length && !topics.length) await this.state.storage.delete(key);
    else await this.state.storage.put(key, { token, lang: LANGS.includes(b.lang) ? b.lang : 'en', coupons, topics, at: Date.now() });
    return Response.json({ ok: true });
  }

  /** Index « sujet -> téléphones », pour retrouver vite qui prévenir. */
  async reindex(key, oldTopics, newTopics) {
    const oldSet = new Set(oldTopics);
    const newSet = new Set(newTopics);
    for (const t of oldSet) {
      if (newSet.has(t)) continue;
      const list = ((await this.state.storage.get(`ix:${t}`)) || []).filter((k) => k !== key);
      if (list.length) await this.state.storage.put(`ix:${t}`, list);
      else await this.state.storage.delete(`ix:${t}`);
    }
    for (const t of newSet) {
      if (oldSet.has(t)) continue;
      const list = (await this.state.storage.get(`ix:${t}`)) || [];
      if (!list.includes(key)) list.push(key);
      await this.state.storage.put(`ix:${t}`, list);
    }
  }

  /** Lecture groupée (le stockage accepte 128 clés par appel). */
  async getMany(keys) {
    const out = new Map();
    for (let i = 0; i < keys.length; i += 128) {
      const m = await this.state.storage.get(keys.slice(i, i + 128));
      for (const [k, v] of m) out.set(k, v);
    }
    return out;
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
      for (const c of u.coupons || []) {
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
    const msgs = jobs.map(([kind, target, title, body, data, tag]) => ({
      ...(kind === 'tips' ? { topic: `${target}_tips` } : { token: target }),
      notification: { title, body },
      data,
      android: { priority: 'HIGH', ttl: '3600s', notification: this.androidNote(tag) },
    }));
    await this.enqueue(msgs, 2);
  }

  androidNote(tag) {
    return { channel_id: 'live', tag, sound: 'default', notification_priority: 'PRIORITY_MAX', default_vibrate_timings: true, visibility: 'PUBLIC' };
  }

  /** File d'attente unique des notifications : 0 = buts, 1 = autres événements du direct, 2 = pronostics/coupons. */
  async enqueue(msgs, prio) {
    if (!msgs.length) return;
    const q = (await this.state.storage.get('outq')) || [];
    for (const m of msgs) q.push({ p: prio, m });
    q.sort((a, b) => a.p - b.p); // tri stable : l'ordre d'arrivée est conservé
    await this.state.storage.put('outq', q.slice(0, OUTQ_MAX));
  }

  /** Envoie ce que la file permet à ce passage ; le reste part au passage suivant (3 s). */
  async drain() {
    const q = (await this.state.storage.get('outq')) || [];
    if (!q.length) return { sent: 0, left: 0 };
    const token = await this.oauth(); // en cas d'échec, la file reste intacte
    const batch = q.slice(0, SEND_BUDGET);
    await this.state.storage.put('outq', q.slice(SEND_BUDGET));
    const res = await Promise.allSettled(batch.map((x) => this.fcm(token, x.m)));
    return { sent: res.filter((x) => x.status === 'fulfilled' && x.value).length, left: q.length - batch.length };
  }

  // ---------- Notifications du direct ----------
  liveText(lang, e, [home, away, league]) {
    const t = TXT[lang] || TXT.en;
    const score = e.hs != null && e.as != null ? `${home} ${e.hs}-${e.as} ${away}` : `${home} - ${away}`;
    const late = e.t === 'goal' && parseInt(e.st, 10) >= 85;
    const min = /^\d/.test(e.st) && !late ? ` (${e.st}')` : '';
    let title = t[e.t];
    let extra = '';
    if (e.t === 'goal') {
      title = (t[e.k] || t.goal).replace('{team}', e.side === 'h' ? home : away);
      // But dans les dernières minutes : on le souligne.
      if (late) extra = ` · ${t.late.replace('{min}', parseInt(e.st, 10))}`;
    }
    if (e.t === 'ft' && e.hs != null && e.as != null) {
      extra = ` · ${e.hs === e.as ? t.draw : t.win.replace('{team}', e.hs > e.as ? home : away)}`;
    }
    return { title, body: `${score}${e.t === 'goal' ? min : ''}${extra}\n${league}` };
  }

  liveMsg(target, lang, e, n) {
    return {
      ...target,
      notification: this.liveText(lang, e, n),
      data: { id: String(e.id), t: e.t },
      android: { priority: 'HIGH', ttl: '600s', notification: this.androidNote(`m${e.id}`) },
    };
  }

  /** Prépare les notifications d'un événement (but, coup d'envoi, mi-temps, fin). */
  async buildLive(e, n) {
    const h = leagueHash(n[2]);
    const msgs = [];
    // Anciennes versions de l'app (abonnées aux sujets Firebase « _l_ / _m_ »).
    for (const lang of LANGS) {
      msgs.push(this.liveMsg({ condition: `'${lang}_l_${h}' in topics || '${lang}_m_${e.id}' in topics` }, lang, e, n));
    }
    // Nouvelle version : envoi direct à chaque téléphone (le plus rapide).
    const topics = LANGS.flatMap((L) => [`${L}_l2_${h}`, `${L}_m2_${e.id}`]);
    const ix = await this.state.storage.get(topics.map((t) => `ix:${t}`));
    const keys = new Set();
    for (const list of ix.values()) for (const k of list || []) keys.add(k);
    if (keys.size > DIRECT_MAX) {
      for (const lang of LANGS) {
        msgs.push(this.liveMsg({ condition: `'${lang}_l2_${h}' in topics || '${lang}_m2_${e.id}' in topics` }, lang, e, n));
      }
    } else if (keys.size) {
      const devs = await this.getMany([...keys]);
      for (const d of devs.values()) {
        if (d?.token) msgs.push(this.liveMsg({ token: d.token }, d.lang || 'en', e, n));
      }
    }
    return msgs;
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
      // Téléphone désinstallé : on l'oublie (coupons et sujets suivis).
      if (message.token && (r.status === 404 || t.includes('UNREGISTERED'))) {
        const key = this.devKey(message.token);
        const d = await this.state.storage.get(key);
        if (d) {
          await this.reindex(key, d.topics || [], []);
          await this.state.storage.delete(key);
        }
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
    // Équipe qui a été menée pendant le match (pour annoncer un renversement) : id -> [dom., ext.]
    const trail = (await this.state.storage.get('trail')) || {};

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
        const side = hs > p[0] ? 'h' : 'a';
        const tr = trail[id] || [false, false];
        fresh.push({ ...base, t: 'goal', side, k: goalKind(side, hs, as, side === 'h' ? tr[0] : tr[1]) });
      }
      if (hs != null && as != null && (hs !== as || trail[id])) {
        const tr = trail[id] || [false, false];
        trail[id] = [tr[0] || hs < as, tr[1] || as < hs];
      }
      if (isHT(st) && !isHT(pst)) fresh.push({ ...base, t: 'ht' });
      if (isFin(st) && p && !isFin(pst)) fresh.push({ ...base, t: 'ft' });
    }
    await this.state.storage.put('live', cur);
    await this.state.storage.put('liveAt', Date.now());
    for (const id of Object.keys(trail)) if (!cur[id]) delete trail[id];
    await this.state.storage.put('trail', trail);

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

    // Notifications : tous les nouveaux événements entrent dans la file (buts en premier).
    if (events.length) {
      if (events.some((e) => !this.names?.[e.id])) await this.loadNames(true);
      events.sort((a, b) => (a.t === 'goal' ? 0 : 1) - (b.t === 'goal' ? 0 : 1));
      for (const e of events) {
        const n = this.names?.[e.id];
        if (!n) continue; // match inconnu du flux : pas de nom à afficher
        await this.enqueue(await this.buildLive(e, n), e.t === 'goal' ? 0 : 1);
      }
    }
    await this.state.storage.put('queue', []);
    const { sent, left } = await this.drain();

    // Pronostics (toutes les 5 min) et coupons (à chaque fin de match) : envoyés au passage suivant,
    // pour ne jamais retarder les notifications du direct.
    const fin = {};
    for (const e of fresh) if (e.t === 'ft') fin[e.id] = [e.hs, e.as];
    try {
      await this.checkCoupons(fin);
      await this.checkTips();
    } catch (e) {
      await this.state.storage.put('err', `${new Date().toISOString()} tips ${e}`);
    }
    const stat = (await this.state.storage.get('stat')) || { sent: 0 };
    stat.at = new Date().toISOString();
    stat.live = live;
    stat.sent = (stat.sent || 0) + sent;
    stat.queue = left;
    await this.state.storage.put('stat', stat);
    const more = ((await this.state.storage.get('outq')) || []).length;
    return live > 0 || more ? FAST : SLOW;
  }

  // ---------- Firebase ----------
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

// Relais des données KOUNADIA (chiffrées) quand GitHub refuse ou bloque la demande du téléphone.
// Gardé 30 s en mémoire : beaucoup d'utilisateurs = une seule lecture GitHub.
const FEED_RE = /^\/feed\/([a-z]+\/[a-z0-9_.-]+\.json)$/;

// Déchiffre un fichier du flux : « KD1. » = clé publique de l'app, « KP1. » = clé Premium (jamais dans l'app).
async function openFeed(text, env) {
  const t = String(text || '').trim();
  const pre = t.slice(0, 4);
  if (pre !== 'KD1.' && pre !== 'KP1.') return t;
  const k = pre === 'KP1.' ? env.PK_KEY : env.KD_KEY;
  if (!k) throw new Error('clé absente');
  const raw = b64(t.slice(4));
  const key = await crypto.subtle.importKey('raw', b64(k), 'AES-GCM', false, ['decrypt']);
  const z = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: raw.slice(0, 12), tagLength: 128 }, key, raw.slice(12));
  const ds = new Blob([z]).stream().pipeThrough(new DecompressionStream('gzip'));
  return new Response(ds).text();
}

// ---------- Contenu Premium : servi seulement avec un ticket valide du serveur KOUNADIA ----------
// Ticket = base64url({uid, exp}) + "." + HMAC-SHA256 (secret partagé avec knd-api). Il expire vite (24 h max).
const PREMIUM = new Set(['pronos/today.json', 'vip/vip.json']);
const unb64url = (s) => b64(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4));
async function ticketOk(req, env) {
  try {
    const t = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();
    const [body, sig] = t.split('.');
    if (!body || !sig || !env.TICKET_SECRET) return false;
    const key = await crypto.subtle.importKey('raw', enc(env.TICKET_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    if (!(await crypto.subtle.verify('HMAC', key, unb64url(sig), enc(body)))) return false;
    const p = JSON.parse(new TextDecoder().decode(unb64url(body)));
    return !!p?.uid && Number(p.exp) > Date.now();
  } catch (_) {
    return false;
  }
}
const premMem = new Map(); // chemin -> [heure, texte déchiffré]
async function premiumFile(path, env) {
  const now = Date.now();
  const c = premMem.get(path);
  if (c && now - c[0] < 60000) return c[1];
  // Contenu réel dans « _p.json » (clé Premium) ; le fichier public sert aux anciennes versions de l'app.
  const raw = (await feedRelay(path.replace(/\.json$/, '_p.json'))) ?? (await feedRelay(path));
  if (raw == null) return null;
  const text = await openFeed(raw, env);
  premMem.set(path, [now, text]);
  return text;
}
const feedMem = new Map(); // chemin -> [heure, texte]

async function feedRelay(path) {
  const now = Date.now();
  const c = feedMem.get(path);
  if (c && now - c[0] < 30000) return c[1];
  const r = await fetch(`${KFEED}/${path}?v=${Math.floor(now / 30000)}`);
  if (!r.ok) return null;
  const text = await r.text();
  if (feedMem.size > 50) feedMem.clear();
  feedMem.set(path, [now, text]);
  return text;
}

// Relais PrimaTips pour la version navigateur (iPhone) : le site refuse les appels directs des navigateurs.
// Gardé 30 s en mémoire : beaucoup d'utilisateurs = une seule lecture.
const ptMem = new Map(); // chemin+requête -> [heure, statut, type, texte]
async function ptRelay(url) {
  const key = url.pathname.slice(3) + url.search;
  const now = Date.now();
  const c = ptMem.get(key);
  if (c && now - c[0] < 30000) return c;
  const r = await fetch(`https://primatips.com${key}`, { headers: UA });
  const v = [now, r.status, r.headers.get('content-type') || 'text/html; charset=utf-8', await r.text()];
  if (ptMem.size > 300) ptMem.clear();
  if (r.ok) ptMem.set(key, v);
  return v;
}

// Autorise l'app navigateur (kounadia.pages.dev) à appeler le robot.
const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-headers': 'content-type, authorization', 'access-control-max-age': '86400' };
function withCors(res) {
  if (res.status === 101 || res.webSocket) return res; // connexion en direct : inchangée
  const h = new Headers(res.headers);
  for (const [k, v] of Object.entries(CORS)) h.set(k, v);
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
}

export default {
  async scheduled(_ev, env, ctx) {
    ctx.waitUntil(poller(env).fetch('https://poller/kick'));
  },
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const url = new URL(req.url);
    const m = FEED_RE.exec(url.pathname);
    if (m) {
      const text = await feedRelay(m[1]).catch(() => null);
      if (text == null) return withCors(new Response('indisponible', { status: 502 }));
      return withCors(new Response(text, { headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' } }));
    }
    if (url.pathname.startsWith('/p/') && req.method === 'GET') {
      const path = url.pathname.slice(3);
      if (!PREMIUM.has(path)) return withCors(new Response('introuvable', { status: 404 }));
      if (!(await ticketOk(req, env))) return withCors(new Response('premium requis', { status: 401 }));
      const text = await premiumFile(path, env).catch(() => null);
      if (text == null) return withCors(new Response('indisponible', { status: 502 }));
      return withCors(new Response(text, { headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'private, no-store' } }));
    }
    if (url.pathname === '/geo') {
      return withCors(new Response(`loc=${req.cf?.country || ''}\n`, { headers: { 'content-type': 'text/plain', 'cache-control': 'no-store' } }));
    }
    if (url.pathname.startsWith('/pt/') && req.method === 'GET') {
      try {
        const [, status, type, text] = await ptRelay(url);
        return withCors(new Response(text, { status, headers: { 'content-type': type, 'cache-control': 'no-store' } }));
      } catch (e) {
        return withCors(new Response('indisponible', { status: 502 }));
      }
    }
    return withCors(await poller(env).fetch(req));
  },
};
