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
import 'pt_match_screen.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

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
  String _filter = 'all';
  Timer? _liveTimer;
  Timer? _fullTimer;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFav();
    _load();
    LogoCache.load().then((_) {
      if (mounted) setState(() {});
    });
    _fullTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load(silent: true));
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollLive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    _fullTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _pollLive();
  }

  String _key(int off) {
    final d = DateTime.now().add(Duration(days: off));
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  List<LiveMatch> _listFor(int off) => _days[_key(off)] ?? const [];

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
        duration: const Duration(seconds: 1),
        content: Text(added ? '⭐ Ajouté aux favoris' : 'Retiré des favoris'),
      ));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('score_favs', _fav.map((e) => '$e').toList());
    } catch (_) {}
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
      _pollLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_days.isEmpty) _error = e.toString();
      });
    }
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

  Future<void> _pollLive() async {
    if (!_active || !_hasLive) return;
    try {
      final live = await ScoresService.live();
      final byId = {for (final m in _listFor(0)) m.id: m};
      final now = DateTime.now();
      for (final l in live) {
        final m = byId[(l['id'] as num?)?.toInt()];
        if (m == null || m.status == 'postponed') continue;
        if (m.date != null && m.date!.isAfter(now)) continue;
        m.hs = (l['hs'] as num?)?.toInt() ?? m.hs;
        m.as_ = (l['as'] as num?)?.toInt() ?? m.as_;
        final st = (l['st'] ?? '').toString().trim();
        if (RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(st)) {
          m.status = 'finished';
          m.minute = null;
        } else {
          m.status = 'live';
          m.minute = RegExp(r'^\d').hasMatch(st) ? "$st'" : (st.toUpperCase() == 'HT' ? 'MT' : st);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<LiveMatch> _filtered(List<LiveMatch> all) {
    switch (_filter) {
      case 'live':
        return all.where((m) => m.status == 'live').toList();
      case 'fav':
        return all.where((m) => _fav.contains(m.id)).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _listFor(_offset);
    final day = DateTime.now().add(Duration(days: _offset));
    final label = ['Hier', "Aujourd'hui", 'Demain'][_offset + 1];

    return Scaffold(
      backgroundColor: K.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                _navBtn(Icons.chevron_left_rounded,
                    _offset > -1 ? () => setState(() => _offset--) : null),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$label (${two(day.day)}/${two(day.month)})',
                          style: const TextStyle(
                              color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                _navBtn(Icons.chevron_right_rounded,
                    _offset < 1 ? () => setState(() => _offset++) : null),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(child: _seg('all', 'Tous', all.length)),
                const SizedBox(width: 6),
                Expanded(
                    child: _seg('live', 'Direct',
                        all.where((m) => m.status == 'live').length,
                        dot: all.any((m) => m.status == 'live'))),
                const SizedBox(width: 6),
                Expanded(child: _seg('fav', 'Favoris', all.where((m) => _fav.contains(m.id)).length)),
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
      shape: const CircleBorder(side: BorderSide(color: K.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
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
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
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
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot) ...[
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
                const SizedBox(width: 5),
              ],
              Text('$label · $count',
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: K.indigo));
    if (_error != null) return kMessage(_error!, onRetry: _load);

    final items = _filtered(all);
    final groups = <String, List<LiveMatch>>{};
    for (final m in items) {
      groups.putIfAbsent(m.leagueLabel, () => []).add(m);
    }

    final children = <Widget>[if (_offline) kOfflineBanner()];
    if (items.isEmpty) {
      children.addAll([
        const SizedBox(height: 60),
        kMessage(_filter == 'live'
            ? 'Aucun match en direct pour le moment.'
            : _filter == 'fav'
                ? 'Fais un appui long sur un match pour l’ajouter à tes favoris.'
                : 'Aucun match pour ce jour.'),
      ]);
    } else {
      children.add(const KndBanner());
      var rows = 0;
      var block = 0;
      for (final e in groups.entries) {
        children
          ..add(_group(e.key, e.value))
          ..add(const SizedBox(height: 10));
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
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
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
              color: const Color(0xFF1F2440),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
                        errorWidget: (_, __, ___) => const SizedBox(width: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  if (hasLive) ...[
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ],
                  Text('${list.length}', style: const TextStyle(color: K.muted, fontSize: 12)),
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
        return Text(m.minute ?? 'Live',
            style: const TextStyle(color: K.red, fontSize: 13, fontWeight: FontWeight.w800));
      case 'finished':
        return const Text('Fin',
            style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700));
      case 'postponed':
        return const Text('Rep.',
            style: TextStyle(color: K.amber, fontSize: 12, fontWeight: FontWeight.w700));
      default:
        return Text(m.date != null ? hm(m.date!) : '--:--',
            style: const TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700));
    }
  }

  Widget _team(String name, int? goals, bool win) {
    return Row(
      children: [
        TeamCrest(name: name, logo: LogoCache.get(name), size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: K.text,
                  fontSize: 13.5,
                  fontWeight: win ? FontWeight.w800 : FontWeight.w500)),
        ),
        const SizedBox(width: 6),
        Text(goals?.toString() ?? '',
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PtMatchScreen(match: m)))
          .then((_) {
        if (mounted) setState(() {});
      }),
      onLongPress: () => _toggleFav(m),
      child: Container(
        color: m.status == 'live' ? const Color(0x14EF4444) : null,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timeCell(m),
                  if (fav) const Icon(Icons.star_rounded, color: K.amber, size: 13),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _team(m.home, h, has && h > a),
                  const SizedBox(height: 5),
                  _team(m.away, a, has && a > h),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (prob != null)
                    Text('$prob %',
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(m.tipShort,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  if (m.tipOdd != null)
                    Text('@${m.tipOdd!.toStringAsFixed(2)}',
                        style: const TextStyle(color: K.muted, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
