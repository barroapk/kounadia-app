import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import '../services/scores_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage, kOfflineBanner, hm, two;
import '../widgets/jersey.dart';
import '../widgets/knd_banner.dart';
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
    _liveTimer = Timer.periodic(Duration(seconds: 30), (_) => _pollLive());
    _sock = LiveSocket.updates.stream.listen(_onSocket);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FavLeagues.set.removeListener(_onFav);
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

  List<LiveMatch> _listFor(int off) => _days[_key(off)] ?? [];

  Future<void> _loadFav() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('score_favs') ?? [];
      if (mounted) setState(() => _fav = l.map(int.parse).toSet());
    } catch (_) {}
  }

  Future<void> _toggleFav(LiveMatch m) async {
    final added = !_fav.contains(m.id);
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
      if (LiveSocket.fresh && LiveSocket.last.isNotEmpty) _onSocket(Map.of(LiveSocket.last));
      _pollLive();
      _applyLogos();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_days.isEmpty) _error = e.toString();
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
    final day = DateTime.now().add(Duration(days: _offset));
    final label = ['Hier', "Aujourd'hui", 'Demain'][_offset + 1];

    return Scaffold(
      backgroundColor: K.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                _navBtn(Icons.chevron_left_rounded,
                    _offset > -1 ? () => setState(() => _offset--) : null),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: T('${tr(label)} (${two(day.day)}/${two(day.month)})',
                          style: TextStyle(
                              color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                _navBtn(Icons.chevron_right_rounded,
                    _offset < 1 ? () => setState(() => _offset++) : null),
                SizedBox(width: 8),
                _navBtn(_search ? Icons.close_rounded : Icons.search_rounded, () => setState(() {
                      _search = !_search;
                      if (!_search) _q = '';
                    })),
              ],
            ),
          ),
          if (_search)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
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
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(child: _seg('all', 'Tous', all.length)),
                SizedBox(width: 6),
                Expanded(
                    child: _seg('live', 'Direct',
                        all.where((m) => m.status == 'live').length,
                        dot: all.any((m) => m.status == 'live'))),
                SizedBox(width: 6),
                Expanded(child: _seg('mine', 'Mes matchs', all.where(_mine).length)),
              ],
            ),
          ),
          Expanded(child: _body(all)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: K.card,
      shape: CircleBorder(side: BorderSide(color: K.border)),
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: onTap == null ? K.border : K.text, size: 24),
        ),
      ),
    );
  }

  Widget _seg(String value, String label, int count, {bool dot = false}) {
    final sel = _view == value;
    return GestureDetector(
      onTap: () => setState(() {
        _filter = value;
        _auto = false;
      }),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? K.indigo : K.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? K.indigo : K.border),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot) ...[
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: K.red, shape: BoxShape.circle)),
                SizedBox(width: 5),
              ],
              T('${tr(label)} · $count',
                  style: TextStyle(
                      color: sel ? Colors.white : K.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ]),
          ),
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
    } else {
      children.add(KndBanner());
      var rows = 0;
      var block = 0;
      final ordered = [
        ...groups.entries.where((e) => FavLeagues.has(e.key)),
        ...groups.entries.where((e) => !FavLeagues.has(e.key)),
      ];
      for (final e in ordered) {
        children
          ..add(_group(e.key, e.value))
          ..add(SizedBox(height: 10));
        rows += e.value.length;
        if (rows ~/ 10 > block) {
          block = rows ~/ 10;
          children.add(KndBanner(afterCards: block * 10, total: items.length));
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
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 0, 12, 96),
        children: children,
      ),
    );
  }

  Widget _group(String title, List<LiveMatch> list) {
    final collapsed = _collapsed.contains(title);
    final hasLive = list.any((m) => m.status == 'live');
    final flag = list.first.flag;
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(_row(list[i]));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => collapsed ? _collapsed.remove(title) : _collapsed.add(title)),
            child: Container(
              color: K.groupHead,
              padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  if (flag.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: flag,
                        width: 18,
                        height: 13,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => SizedBox(width: 18),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  Expanded(
                    child: T(frLeague(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  if (hasLive) ...[
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: K.red, shape: BoxShape.circle)),
                    SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: () => FavLeagues.toggle(title),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(FavLeagues.has(title) ? Icons.star_rounded : Icons.star_border_rounded,
                          color: FavLeagues.has(title) ? K.amber : K.muted, size: 19),
                    ),
                  ),
                  T('${list.length}', style: TextStyle(color: K.muted, fontSize: 12)),
                  Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                      color: K.muted, size: 22),
                ],
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _timeCell(LiveMatch m) {
    switch (m.status) {
      case 'live':
        return T(m.minute ?? 'Live',
            style: TextStyle(color: K.red, fontSize: 13, fontWeight: FontWeight.w800));
      case 'finished':
        return T('Fin',
            style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700));
      case 'postponed':
        return T('Rep.',
            style: TextStyle(color: K.amber, fontSize: 12, fontWeight: FontWeight.w700));
      default:
        return T(m.date != null ? hm(m.date!) : '--:--',
            style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700));
    }
  }

  Widget _team(String name, int? goals, bool win) {
    return Row(
      children: [
        TeamCrest(name: name, logo: _logos[name] ?? LogoCache.get(name), size: 16),
        SizedBox(width: 7),
        Expanded(
          child: T(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: K.text,
                  fontSize: 13.5,
                  fontWeight: win ? FontWeight.w800 : FontWeight.w500)),
        ),
        SizedBox(width: 6),
        T(goals?.toString() ?? '',
            style: TextStyle(
                color: m_scoreColor(goals),
                fontSize: 13.5,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Color m_scoreColor(int? g) => g == null ? K.muted : K.text;

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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumGate(
                    standalone: true,
                    title: "Analyse du match",
                    pitch: "Statistiques, forme, confrontations et marchés détaillés pour chaque match.",
                    perks: ["Probabilités et cotes : 1X2, buts, les deux marquent","Forme récente et classement","Confrontations directes","Analyse KOUNADIA du match"],
                    icon: Icons.query_stats_rounded,
                    child: PtMatchScreen(match: m))))
          .then((_) {
        if (mounted) setState(() {});
      }),
      onLongPress: () => _toggleFav(m),
      child: Container(
        color: m.status == 'live' ? Color(0x14EF4444) : null,
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timeCell(m),
                  if (fav) Icon(Icons.star_rounded, color: K.amber, size: 13),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _team(m.home, h, has && h > a),
                  SizedBox(height: 5),
                  _team(m.away, a, has && a > h),
                ],
              ),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (prob != null)
                    T('$prob %',
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
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
