import '../widgets/k_err.dart';
import '../services/interests.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import '../services/scores_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage, kOfflineBanner, hm, two;
import '../widgets/jersey.dart';
import '../widgets/knd_banner.dart';
import '../widgets/big_matches.dart';
import '../widgets/hl_list.dart';
import '../services/highlights.dart';
import '../widgets/video_open.dart';
import '../services/logo_cache.dart';
import '../services/markets_service.dart';
import 'pt_match_screen.dart';
import '../widgets/premium_gate.dart';
import 'fav_leagues_screen.dart';
import '../services/fav_leagues.dart';
import '../services/notif.dart';
import '../services/live_socket.dart';
import '../services/primatips_service.dart' show frLeague;
import '../l10n/tr.dart';
import '../config/store.dart';

class ScoresScreen extends StatefulWidget {
  ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> with WidgetsBindingObserver {
  Map<String, List<LiveMatch>> _days = {};
  int _offset = 0;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  Set<int> _fav = {};
  final Set<String> _collapsed = {};
  final Map<String, String> _logos = {};
  String _filter = 'all';
  // Mes matchs choisi automatiquement : si aucun favori ce jour-là, on montre Tous.
  bool _auto = false;
  String _view = 'all';
  Timer? _liveTimer;
  Timer? _fullTimer;
  bool _active = true;
  StreamSubscription<Map<int, (int?, int?, String)>>? _sock;
  bool _onlyFav = false;
  int _tick = 0;
  String _q = '';
  bool _search = false;

  void _onFav() {
    if (mounted) setState(() {});
  }

  bool _mine(LiveMatch m) => FavLeagues.has(m.leagueLabel) || _fav.contains(m.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Highlights.load();
    Highlights.changed.addListener(_onFav);
    _loadFav();
    FavLeagues.load().then((_) {
      if (FavLeagues.set.value.isNotEmpty && _filter == 'all') {
        _filter = 'mine';
        _auto = true;
      }
      _onFav();
    });
    FavLeagues.set.addListener(_onFav);
    _load();
    LogoCache.load().then((_) {
      if (mounted) setState(() {});
    });
    // Toutes les 5 min, ou chaque minute tant que l'appli est hors connexion.
    _fullTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _tick++;
      if (_active && (_offline || _tick % 5 == 0)) _load(silent: true);
    });
    _liveTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _pollLive();
      // La minute avance à l'écran même si le site source tarde à la mettre à jour.
      if (_active && mounted && _listFor(0).any((m) => m.status == 'live')) setState(() {});
    });
    _sock = LiveSocket.updates.stream.listen(_onSocket);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FavLeagues.set.removeListener(_onFav);
    Highlights.changed.removeListener(_onFav);
    _liveTimer?.cancel();
    _fullTimer?.cancel();
    _sock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _load(silent: true);
      _pollLive();
    }
  }

  String _key(int off) {
    final d = DateTime.now().add(Duration(days: off));
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  List<LiveMatch> _listFor(int off) {
    final l = _days[_key(off)] ?? [];
    final t = DateTime.now();
    for (final m in l) {
      m.fixStale(t);
    }
    for (final m in _days[_key(-1)] ?? const <LiveMatch>[]) {
      m.fixStale(t);
    }
    if (off != 0) return l;
    // Après minuit : les matchs d'hier soir (en cours ou finis depuis peu) restent aussi dans « Aujourd'hui »,
    // avec leur direct, pendant 4 h après le coup d'envoi.
    final now = DateTime.now();
    final late = (_days[_key(-1)] ?? [])
        .where((m) => m.date != null && m.status != 'postponed' && now.difference(m.date!).inMinutes < 240)
        .toList();
    return late.isEmpty ? l : [...late, ...l];
  }

  Future<void> _loadFav() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('score_favs') ?? [];
      if (mounted) setState(() => _fav = l.map(int.parse).toSet());
    } catch (_) {}
  }

  Timer? _searchT;

  /// Recherche d'une équipe (après 3 s sans taper) : centre d'intérêt pour les infos personnalisées.
  void _noteSearch(String v) {
    _searchT?.cancel();
    final q = _sn(v.trim());
    if (q.length < 3) return;
    _searchT = Timer(Duration(seconds: 3), () {
      final teams = <String>{};
      for (final l in _days.values) {
        for (final m in l) {
          if (_sn(m.home).contains(q)) teams.add(m.home);
          if (_sn(m.away).contains(q)) teams.add(m.away);
        }
      }
      if (teams.isNotEmpty && teams.length <= 3) {
        for (final t in teams) {
          Interests.search(t);
        }
      }
    });
  }

  Future<void> _toggleFav(LiveMatch m) async {
    final added = !_fav.contains(m.id);
    if (added) Interests.match(m.home, m.away, m.leagueLabel, w: 3);
    setState(() => added ? _fav.add(m.id) : _fav.remove(m.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: Duration(seconds: 1),
        content: T(added ? '⭐ Ajouté aux favoris' : 'Retiré des favoris'),
      ));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('score_favs', _fav.map((e) => '$e').toList());
    } catch (_) {}
    Notif.sync();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _days.isEmpty;
        _error = null;
      });
    }
    try {
      final (days, offline) = await ScoresService.load();
      if (!mounted) return;
      setState(() {
        _days = days;
        _offline = offline;
        _loading = false;
        _error = null;
      });
      // Le fichier des scores peut avoir quelques minutes de retard : le direct du robot repasse par-dessus.
      if (LiveSocket.connected && LiveSocket.last.isNotEmpty) _onSocket(Map.of(LiveSocket.last));
      _pollLive();
      _applyLogos();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_days.isEmpty) _error = kErr(e);
      });
    }
  }

  Future<void> _applyLogos() async {
    try {
      final mk = await MarketsService.load();
      final map = <String, String>{};
      for (final l in _days.values) {
        for (final m in l) {
          final x = mk[m.id];
          if (x == null) continue;
          if (x.hl != null) map[m.home] = x.hl!;
          if (x.al != null) map[m.away] = x.al!;
        }
      }
      if (map.isNotEmpty) {
        if (mounted) setState(() => _logos.addAll(map));
        await LogoCache.putAll(map);
      }
    } catch (_) {}
  }

  bool get _hasLive {
    final now = DateTime.now();
    return _listFor(0).any((m) =>
        m.status == 'live' ||
        (m.status == 'upcoming' &&
            m.date != null &&
            now.isAfter(m.date!) &&
            now.difference(m.date!).inMinutes < 150));
  }

  /// Applique un score du direct (robot en temps réel, ou site en secours).
  void _applyLive(Map<int, LiveMatch> byId, int? id, int? hs, int? as_, String st, DateTime now) {
    final m = byId[id];
    if (m == null || m.status == 'postponed') return;
    if (m.date != null && m.date!.isAfter(now)) return;
    m.hs = hs ?? m.hs;
    m.as_ = as_ ?? m.as_;
    if (RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(st)) {
      m.status = 'finished';
      m.minute = null;
    } else {
      m.status = 'live';
      m.minute = RegExp(r'^\d').hasMatch(st) ? "$st'" : (st.toUpperCase() == 'HT' ? 'MT' : st);
    }
    // Direct figé (ex. bloqué à 7' depuis des heures) : reporté ou terminé.
    m.fixStale(now);
  }

  void _onSocket(Map<int, (int?, int?, String)> u) {
    if (!mounted) return;
    final byId = {for (final m in _listFor(0)) m.id: m};
    final now = DateTime.now();
    u.forEach((id, v) => _applyLive(byId, id, v.$1, v.$2, v.$3, now));
    setState(() {});
  }

  Future<void> _pollLive() async {
    // Le robot pousse déjà le direct en temps réel : interrogation du site seulement en secours.
    if (!_active || !_hasLive || LiveSocket.fresh) return;
    try {
      final live = await ScoresService.live();
      final byId = {for (final m in _listFor(0)) m.id: m};
      final now = DateTime.now();
      for (final l in live) {
        _applyLive(byId, (l['id'] as num?)?.toInt(), (l['hs'] as num?)?.toInt(), (l['as'] as num?)?.toInt(),
            (l['st'] ?? '').toString().trim(), now);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<LiveMatch> _filtered(List<LiveMatch> all) {
    final q = _sn(_q.trim());
    if (q.isNotEmpty) {
      return all.where((m) => _sn(m.home).contains(q) || _sn(m.away).contains(q) ||
          _sn(frLeague(m.leagueLabel)).contains(q) || _sn(m.leagueLabel).contains(q)).toList();
    }
    switch (_view) {
      case 'live':
        return all.where((m) => m.status == 'live' && (!_onlyFav || _mine(m))).toList();
      case 'mine':
        return all.where(_mine).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _listFor(_offset);
    _view = _auto && _filter == 'mine' && !_loading && !all.any(_mine) ? 'all' : _filter;

    return Scaffold(
      backgroundColor: K.bg,
      body: Column(
        children: [
          // Jour : 3 pastilles (Hier · Aujourd'hui · Demain) avec la date, et la recherche.
          Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [for (final o in const [-1, 0, 1]) Expanded(child: _dayPill(o))]),
                ),
              ),
              SizedBox(width: 10),
              _navBtn(_search ? Icons.close_rounded : Icons.search_rounded, () => setState(() {
                    _search = !_search;
                    if (!_search) _q = '';
                  })),
            ]),
          ),
          if (_search)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) {
                  setState(() => _q = v);
                  _noteSearch(v);
                },
                style: TextStyle(color: K.text),
                decoration: InputDecoration(
                  hintText: tr('Équipe ou championnat…'),
                  hintStyle: TextStyle(color: K.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: K.muted),
                  filled: true,
                  fillColor: K.card,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
                ),
              ),
            ),
          // Filtres : pastilles qui défilent (Tous, Direct, Mes matchs, Temps forts) avec leur nombre.
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14),
              children: [
                _seg('all', 'Tous', all.length, icon: Icons.grid_view_rounded),
                _seg('live', 'Direct', all.where((m) => m.status == 'live').length, dot: all.any((m) => m.status == 'live')),
                // Temps forts juste après « Direct », en rouge : on voit tout de suite qu'il y a des vidéos.
                ValueListenableBuilder<int>(
                  valueListenable: Highlights.changed,
                  builder: (_, __, ___) => _seg('hl', 'Temps forts', Highlights.recent().length, icon: Icons.play_circle_rounded),
                ),
                _seg('mine', 'Mes matchs', all.where(_mine).length, icon: Icons.star_rounded),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
              child: _view == 'hl'
                  ? HighlightsList(byId: {for (final l in _days.values) for (final m in l) m.id: m})
                  : _body(all)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: K.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: onTap == null ? K.border : K.text, size: 21)),
      ),
    );
  }

  /// Pastille d'un jour : « Aujourd'hui » et sa date ; la pastille choisie est pleine (dégradé).
  Widget _dayPill(int o) {
    final sel = _offset == o;
    final d = DateTime.now().add(Duration(days: o));
    final label = ['Hier', "Aujourd'hui", 'Demain'][o + 1];
    return GestureDetector(
      onTap: () => setState(() => _offset = o),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: sel ? LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: sel ? [BoxShadow(color: Color(0x554F46E5), blurRadius: 10, offset: Offset(0, 3))] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              T(label, style: TextStyle(color: sel ? Colors.white : K.text, fontSize: 13, fontWeight: FontWeight.w800, height: 1.1)),
              Text('${two(d.day)}/${two(d.month)}',
                  style: TextStyle(color: sel ? Colors.white70 : K.muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _seg(String value, String label, int count, {bool dot = false, IconData? icon}) {
    final sel = _view == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _filter = value;
          _auto = false;
        }),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          padding: EdgeInsets.fromLTRB(12, 0, 6, 0),
          decoration: BoxDecoration(
            color: sel ? K.indigo : K.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot)
              Container(width: 8, height: 8, decoration: BoxDecoration(color: sel ? Colors.white : K.red, shape: BoxShape.circle))
            else if (icon != null)
              Icon(icon, size: 16, color: sel ? Colors.white : value == 'mine' ? K.amber : value == 'hl' && count > 0 ? K.red : K.muted),
            SizedBox(width: 6),
            T(label, style: TextStyle(color: sel ? Colors.white : K.text, fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: sel ? Colors.white24 : value == 'hl' && count > 0 ? K.red : K.bg, borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: TextStyle(color: sel || (value == 'hl' && count > 0) ? Colors.white : K.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body(List<LiveMatch> all) {
    if (_loading) return Center(child: CircularProgressIndicator(color: K.indigo));
    if (_error != null) return kMessage(_error!, onRetry: _load);

    final items = _filtered(all);
    final groups = <String, List<LiveMatch>>{};
    for (final m in items) {
      groups.putIfAbsent(m.leagueLabel, () => []).add(m);
    }

    final children = <Widget>[
      if (_offline) kOfflineBanner(),
      if (_view == 'live' && FavLeagues.set.value.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.star_rounded, color: K.amber, size: 18),
            SizedBox(width: 6),
            Expanded(child: T('Uniquement mes championnats', style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600))),
            Switch(value: _onlyFav, activeColor: K.amber, onChanged: (v) => setState(() => _onlyFav = v)),
          ]),
        ),
    ];
    if (items.isEmpty) {
      children.addAll([
        SizedBox(height: 60),
        kMessage(_q.trim().isNotEmpty
            ? 'Aucun match trouvé pour « ${_q.trim()} ».'
            : _view == 'live'
            ? 'Aucun match en direct pour le moment.'
            : _view == 'mine'
                ? 'Aucun match de tes championnats ce jour.\nChoisis-les avec ⭐ (ou appui long sur un match).'
                : 'Aucun match pour ce jour.'),
        if (_view == 'mine')
          Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: K.indigo),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavLeaguesScreen())),
              icon: Icon(Icons.star_rounded),
              label: T('Choisir mes championnats'),
            ),
          ),
      ]);
    }
    // Liste construite au fil du défilement (des centaines de matchs avec footlive) : seuls les
    // championnats visibles à l'écran sont dessinés, le direct reste fluide.
    final makers = <Widget Function()>[for (final w in children) () => w];
    // En haut : les grands matchs du jour (défilent seuls), à la place de la première pub.
    // Seulement les matchs du jour choisi (Hier, Aujourd'hui, Demain), avec leur direct.
    final big = _q.trim().isEmpty && _view != 'live' ? bigMatches(_days[_key(_offset)] ?? const <LiveMatch>[]) : const <LiveMatch>[];
    if (big.isNotEmpty) {
      makers.insert(_offline ? 1 : 0, () => BigMatchesCarousel(
            key: ValueKey('big$_offset'),
            matches: big,
            logo: (n) => _logos[n] ?? LogoCache.get(n),
            onOpen: _open,
          ));
    }
    if (items.isNotEmpty) {
      if (big.isEmpty) makers.add(() => KndBanner());
      var rows = 0;
      var block = 0;
      final ordered = [
        ...groups.entries.where((e) => FavLeagues.has(e.key)),
        ...groups.entries.where((e) => !FavLeagues.has(e.key)),
      ];
      for (final e in ordered) {
        makers.add(() => Padding(padding: EdgeInsets.only(bottom: 14), child: _group(e.key, e.value)));
        rows += e.value.length;
        if (rows ~/ 10 > block) {
          block = rows ~/ 10;
          final b = block;
          makers.add(() => KndBanner(afterCards: b * 10, total: items.length));
        }
      }
    }

    return RefreshIndicator(
      color: K.indigo,
      backgroundColor: K.card,
      onRefresh: () {
        BannerService.reload();
        return _load();
      },
      child: ListView.builder(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14, 0, 14, 110),
        itemCount: makers.length,
        itemBuilder: (_, i) => makers[i](),
      ),
    );
  }

  Widget _group(String title, List<LiveMatch> list) {
    final collapsed = _collapsed.contains(title);
    final hasLive = list.any((m) => m.status == 'live');
    final flag = list.first.flag;
    final fav = FavLeagues.has(title);
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, margin: EdgeInsets.only(left: 64), color: K.border.withAlpha(140)));
        rows.add(_row(list[i]));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(K.dark ? 40 : 14), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => collapsed ? _collapsed.remove(title) : _collapsed.add(title)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 8, collapsed ? 12 : 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: flag.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: flag,
                            width: 22,
                            height: 16,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(width: 22, height: 16, color: K.bg),
                          )
                        : Container(width: 22, height: 16, color: K.bg, child: Icon(Icons.public_rounded, size: 12, color: K.muted)),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: T(frLeague(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.1)),
                  ),
                  if (hasLive)
                    Container(
                      margin: EdgeInsets.only(left: 6),
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: K.red.withAlpha(36), borderRadius: BorderRadius.circular(8)),
                      child: T('LIVE', style: TextStyle(color: K.red, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                    ),
                  GestureDetector(
                    onTap: () => FavLeagues.toggle(title),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded, color: fav ? K.amber : K.muted, size: 21),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(10)),
                    child: Text('${list.length}', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: K.muted, size: 22),
                ],
              ),
            ),
          ),
          ...rows,
          if (!collapsed) SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _timeCell(LiveMatch m) {
    switch (m.status) {
      case 'live':
        final st = LiveSocket.last[m.id]?.$3;
        final mn = (st == null ? null : LiveSocket.minuteOf(m.id, st)) ?? m.minute ?? 'Live';
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(color: K.red.withAlpha(34), borderRadius: BorderRadius.circular(9)),
          child: T(mn, style: TextStyle(color: K.red, fontSize: 12.5, fontWeight: FontWeight.w900)),
        );
      case 'finished':
        return T('Fin', style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w800));
      case 'postponed':
        return T('Rep.', style: TextStyle(color: K.amber, fontSize: 12, fontWeight: FontWeight.w800));
      default:
        return T(m.date != null ? hm(m.date!) : '--:--', style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800));
    }
  }

  Widget _team(String name, int? goals, bool win) {
    return Row(
      children: [
        TeamCrest(name: name, logo: _logos[name] ?? LogoCache.get(name), size: 20),
        SizedBox(width: 9),
        Expanded(
          child: T(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: K.text, fontSize: 14, fontWeight: win ? FontWeight.w800 : FontWeight.w500)),
        ),
        SizedBox(width: 8),
        SizedBox(
          width: 22,
          child: Text(goals?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(color: win ? K.text : m_scoreColor(goals), fontSize: 15.5, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Color m_scoreColor(int? g) => g == null ? K.muted : K.text;

  /// Vidéo des temps forts d'un match terminé depuis moins de 3 jours (sinon null).
  HlVideo? _hlOf(LiveMatch m) {
    if (m.status != 'finished' || m.date == null || DateTime.now().difference(m.date!) > Duration(days: 3)) return null;
    return Highlights.of(m.id);
  }

  /// Pastille rouge « ▶ Vidéo » : bien visible dans la liste, ouvre directement les temps forts.
  Widget _hlPill(LiveMatch m, HlVideo v) => GestureDetector(
        onTap: () => openHighlight(context, v, title: '${m.home} - ${m.away}', src: 'liste'),
        child: Container(
          padding: EdgeInsets.fromLTRB(3, 2, 7, 2),
          decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
            T('Vidéo', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  void _open(LiveMatch m) {
    // Match venu de footlive (numéro négatif) : score et direct seulement, pas de fiche d'analyse.
    if (m.id < 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: Duration(seconds: 2), content: T("Pas d'analyse détaillée pour ce match : score et direct seulement.")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumGate(
              standalone: true,
              title: "Analyse du match",
              pitch: "Statistiques, forme, confrontations et marchés détaillés pour chaque match.",
              perks: ["Probabilités et cotes : 1X2, buts, les deux marquent","Forme récente et classement","Confrontations directes","Analyse KOUNADIA du match"],
              icon: Icons.query_stats_rounded,
              child: PtMatchScreen(match: m))))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _row(LiveMatch m) {
    final h = m.hs;
    final a = m.as_;
    final has = h != null && a != null;
    final fav = _fav.contains(m.id);
    final color = m.tipStatus == 'won'
        ? K.green
        : m.tipStatus == 'lost'
            ? K.red
            : K.pending;
    final prob = m.tipProb;

    return InkWell(
      // Match venu de footlive (numéro négatif) : score et direct seulement, pas de fiche d'analyse.
      onTap: () => _open(m),
      onLongPress: () => _toggleFav(m),
      child: Container(
        color: m.status == 'live' ? Color(0x0FEF4444) : null,
        padding: EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timeCell(m),
                  if (_hlOf(m) != null) ...[
                    SizedBox(height: 5),
                    _hlPill(m, _hlOf(m)!),
                  ],
                  if (fav) Icon(Icons.star_rounded, color: K.amber, size: 13),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _team(m.home, h, has && h > a),
                  SizedBox(height: 8),
                  _team(m.away, a, has && a > h),
                ],
              ),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (kV2 && m.tipShort.isNotEmpty)
                    // V2 : le code du pari bien visible (1, X2…), puis la confiance.
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withAlpha(36), borderRadius: BorderRadius.circular(8)),
                      child: T(m.tipShort, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  if (prob != null)
                    T('$prob %',
                        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  if (!kV2)
                    T(m.tipShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  if (m.tipOdd != null)
                    T('@${m.tipOdd!.toStringAsFixed(2)}',
                        style: TextStyle(color: K.muted, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sn(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');
