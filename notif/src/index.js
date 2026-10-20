// KOUNADIA · robot de notifications en direct (Cloudflare Worker + Durable Object).
// Toutes les 3 s pendant les matchs : lit le direct PrimaTips, détecte buts / coup d'envoi /
// mi-temps / fin, et envoie la notification Firebase aux abonnés du championnat ou du match.

const LIVE_URL = 'https://primatips.com/liveresults?day=0';
const FEED_URL = 'https://raw.githubusercontent.com/barroapk/kfeed/scores/scores.json';
const UA = { 'User-Agent': 'KOUNADIA-App/1.0' };
const FAST = 3000; // matchs en cours
const SLOW = 20000; // aucun match en cours
const LANGS = ['fr', 'en', 'pt', 'es', 'ar'];
const MAX_EVENTS_PER_TICK = 8; // 5 envois par événement : reste sous la limite d'appels

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
    const r = await fetch(`${FEED_URL}?v=${Math.floor(Date.now() / 60000)}`);
    if (!r.ok) return;
    let text = (await r.text()).trim();
    if (text.startsWith('KD1.')) {
      const raw = b64(text.slice(4));
      const key = await crypto.subtle.importKey('raw', b64(this.env.KD_KEY), 'AES-GCM', false, ['decrypt']);
      const z = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: raw.slice(0, 12), tagLength: 128 }, key, raw.slice(12));
      const ds = new Blob([z]).stream().pipeThrough(new DecompressionStream('gzip'));
      text = await new Response(ds).text();
    }
    const d = JSON.parse(text);
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
