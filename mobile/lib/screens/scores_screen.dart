import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import '../services/scores_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage, kOfflineBanner, hm;
import '../widgets/jersey.dart';
import '../widgets/knd_banner.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> with WidgetsBindingObserver {
  List<LiveMatch> _all = [];
  bool _loading = true;
  bool _offline = false;
  String? _error;
  Set<int> _fav = {};
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

  Future<void> _loadFav() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('score_favs') ?? [];
      if (mounted) setState(() => _fav = l.map(int.parse).toSet());
    } catch (_) {}
  }

  Future<void> _toggleFav(int id) async {
    setState(() => _fav.contains(id) ? _fav.remove(id) : _fav.add(id));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('score_favs', _fav.map((e) => '$e').toList());
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _all.isEmpty;
        _error = null;
      });
    }
    try {
      final (list, offline) = await ScoresService.load();
      if (!mounted) return;
      setState(() {
        _all = list;
        _offline = offline;
        _loading = false;
        _error = null;
      });
      _pollLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_all.isEmpty) _error = e.toString();
      });
    }
  }

  bool get _hasLive {
    final now = DateTime.now();
    return _all.any((m) =>
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
      final byId = {for (final m in _all) m.id: m};
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

  List<LiveMatch> get _visible {
    switch (_filter) {
      case 'live':
        return _all.where((m) => m.status == 'live').toList();
      case 'fav':
        return _all.where((m) => _fav.contains(m.id)).toList();
      default:
        return _all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: Builder(builder: (context) {
        if (_loading) return const Center(child: CircularProgressIndicator(color: K.indigo));
        if (_error != null) return kMessage(_error!, onRetry: _load);
        final items = _visible;
        final liveCount = _all.where((m) => m.status == 'live').length;
        final children = <Widget>[
          if (_offline) kOfflineBanner(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('all', 'Tous · ${_all.length}'),
              _chip('live', 'En direct · $liveCount', dot: liveCount > 0),
              _chip('fav', 'Favoris · ${_all.where((m) => _fav.contains(m.id)).length}'),
            ]),
          ),
          const SizedBox(height: 14),
        ];
        if (items.isEmpty) {
          children.addAll([
            const SizedBox(height: 60),
            kMessage(_filter == 'live'
                ? 'Aucun match en direct pour le moment.'
                : _filter == 'fav'
                    ? 'Touche l’étoile d’un match pour l’ajouter à tes favoris.'
                    : "Aucun match aujourd'hui."),
          ]);
        } else {
          children.add(const KndBanner());
          var n = 0;
          for (final m in items) {
            n++;
            children
              ..add(_card(m))
              ..add(const SizedBox(height: 12))
              ..add(KndBanner(afterCards: n, total: items.length));
          }
        }
        return RefreshIndicator(
          color: K.indigo,
          backgroundColor: K.card,
          onRefresh: () => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: children,
          ),
        );
      }),
    );
  }

  Widget _chip(String value, String label, {bool dot = false}) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? K.indigo : K.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? K.indigo : K.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot) ...[
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : K.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _timeCell(LiveMatch m) {
    Widget child;
    switch (m.status) {
      case 'live':
        child = Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text(m.minute ?? 'Live',
              style: const TextStyle(color: K.red, fontSize: 15, fontWeight: FontWeight.w800)),
        ]);
        break;
      case 'finished':
        child = const Text('Fin',
            style: TextStyle(color: K.muted, fontSize: 14, fontWeight: FontWeight.w700));
        break;
      case 'postponed':
        child = const Text('Reporté',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.amber, fontSize: 11.5, fontWeight: FontWeight.w700));
        break;
      default:
        child = Text(m.date != null ? hm(m.date!) : '--:--',
            style: const TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w800));
    }
    return Container(
      width: 58,
      color: const Color(0xFF1F2440),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _teamLine(String name, int? goals, bool bold) {
    return Row(
      children: [
        TeamCrest(name: name, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: K.text,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 22,
          child: Text(goals?.toString() ?? '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: goals == null ? K.muted : K.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _card(LiveMatch m) {
    final fav = _fav.contains(m.id);
    final h = m.hs;
    final a = m.as_;
    final hasScore = h != null && a != null;
    final tipColor = m.tipStatus == 'won'
        ? K.green
        : m.tipStatus == 'lost'
            ? K.red
            : K.pending;
    final prob = m.tipProb;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: m.status == 'live' ? const Color(0x66EF4444) : K.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _toggleFav(m.id),
                  icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? K.amber : K.muted, size: 24),
                ),
                if (m.flag.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CachedNetworkImage(
                      imageUrl: m.flag,
                      width: 22,
                      height: 16,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(width: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(m.leagueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: K.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Container(height: 1, color: K.border),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _timeCell(m),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _teamLine(m.home, h, hasScore && h > a),
                        const SizedBox(height: 12),
                        _teamLine(m.away, a, hasScore && a > h),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: K.border),
                SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (prob != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (m.tipStatus == 'won' || m.tipStatus == 'lost')
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                      m.tipStatus == 'won'
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      color: tipColor,
                                      size: 16),
                                ),
                              Text('$prob %',
                                  style: TextStyle(
                                      color: tipColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(m.tipShort,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                color: tipColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if (m.tipOdd != null) ...[
                          const SizedBox(height: 4),
                          Text('cote ${m.tipOdd!.toStringAsFixed(2)}',
                              style: const TextStyle(color: K.muted, fontSize: 11.5)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
