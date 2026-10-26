import '../widgets/k_err.dart';
import '../config/store.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/coupon.dart';
import '../models/live_match.dart';
import '../services/coupon_engine.dart';
import '../services/analytics.dart';
import '../services/coupon_store.dart';
import '../services/scores_service.dart';
import '../services/live_socket.dart';
import '../services/v2_service.dart';
import '../models/v2.dart';
import '../services/markets_service.dart';
import '../widgets/forecast_card.dart' show K, hm, two, kMessage;
import '../widgets/k_ui.dart';
import '../widgets/knd_banner.dart';
import '../widgets/coupon_receipt.dart';
import 'pt_match_screen.dart';
import '../l10n/tr.dart';

class CouponTab extends StatefulWidget {
  CouponTab({super.key});

  @override
  State<CouponTab> createState() => _CouponTabState();
}

class _CouponTabState extends State<CouponTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  CouponCriteria _c = CouponCriteria.balanced();
  String _preset = 'eq';
  bool _advanced = false;
  int _view = 0;
  bool _busy = false;
  String? _msg;
  int _analyzed = 0;
  List<Coupon> _results = [];
  final Set<String> _shown = {};
  List<Coupon> _saved = [];
  Timer? _timer;
  Map<String, List<LiveMatch>> _days = {};
  Map<int, MatchMarkets> _mk = {};

  static final _oMin = 1.5;
  static final _oMax = 50.0;
  double _toOdd(double v) => (_oMin * math.pow(_oMax / _oMin, v)).toDouble();
  double _fromOdd(double o) => (math.log(o / _oMin) / math.log(_oMax / _oMin)).clamp(0.0, 1.0).toDouble();
  double _r(double v) => v < 10 ? (v * 10).round() / 10 : (v * 2).round() / 2;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _timer = Timer.periodic(Duration(minutes: 2), (_) {
      if (_view == 1) _loadSaved();
    });
    _sock = LiveSocket.updates.stream.listen(_onLive);
  }

  StreamSubscription<Map<int, (int?, int?, String)>>? _sock;

  /// Direct du robot : les matchs de mes coupons passent en cours / gagné / perdu tout de suite.
  void _onLive(Map<int, (int?, int?, String)> u) {
    if (!mounted || _saved.isEmpty) return;
    final mine = {for (final c in _saved) for (final l in c.legs) l.matchId};
    if (!u.keys.any(mine.contains)) return;
    final by = _byId;
    var changed = false;
    u.forEach((id, v) {
      final m = by[id];
      if (m != null && mine.contains(id) && m.applyLive(v.$1, v.$2, v.$3)) changed = true;
    });
    if (!changed) return;
    for (final c in _saved) {
      CouponEngine.refresh(c, by, V2Service.last?.res ?? const {});
    }
    setState(() {});
    CouponStore.saveAll(_saved);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sock?.cancel();
    super.dispose();
  }

  String _key(int off) {
    final d = DateTime.now().add(Duration(days: off));
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Map<int, LiveMatch> get _byId => {for (final l in _days.values) for (final m in l) m.id: m};

  Future<void> _fetch() async {
    final (d, _) = await ScoresService.load();
    _days = d;
    try {
      _mk = await MarketsService.load();
    } catch (_) {}
    try {
      await V2Service.shared(); // liste « Créer coupon » du moteur + résultats des matchs
    } catch (_) {}
  }

  Future<void> _loadSaved() async {
    final l = await CouponStore.all();
    if (mounted) setState(() => _saved = l);
    try {
      await _fetch();
      final by = _byId;
      // Le fichier des scores peut avoir quelques minutes de retard : on remet le direct du robot par-dessus.
      LiveSocket.last.forEach((id, v) => by[id]?.applyLive(v.$1, v.$2, v.$3));
      for (final c in l) {
        CouponEngine.refresh(c, by, V2Service.last?.res ?? const {});
      }
      await CouponStore.saveAll(l);
      if (mounted) setState(() => _saved = l);
    } catch (_) {}
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: T(m), duration: Duration(seconds: 2)));
  }

  void _applyPreset(String k) {
    final p = _c.period;
    setState(() {
      _c = k == 'safe'
          ? CouponCriteria.safe()
          : k == 'bold'
              ? CouponCriteria.bold()
              : CouponCriteria.balanced();
      _c.period = p;
      _preset = k;
    });
  }

  Future<void> _generate({bool more = false}) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (!more || _days.isEmpty) await _fetch();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = kErr(e);
        });
      }
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: 50));
    final keys = _c.period == 0
        ? [_key(0)]
        : _c.period == 1
            ? [_key(1)]
            : [_key(0), _key(1)];
    // Liste complète du moteur KOUNADIA (toutes catégories, matchs hors PrimaTips compris), aujourd'hui ET demain,
    // refaite toutes les 30 min avec les cotes du moment. Sans elle (hors ligne) : les matchs PrimaTips.
    String dayOf(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
    final live = V2Service.last?.pool ?? const <V2PoolMatch>[];
    final all = live.isNotEmpty ? live : (V2Service.last?.today?.pool ?? const <V2PoolMatch>[]);
    final pool = [for (final m in all) if (m.date != null && keys.contains(dayOf(m.date!))) m];
    final usePool = pool.isNotEmpty;
    final matches = usePool ? <LiveMatch>[] : keys.expand((k) => _days[k] ?? <LiveMatch>[]).toList();
    final cands = [
      if (usePool) ...CouponEngine.poolCandidates(pool, _c),
      ...CouponEngine.candidates(matches, _c, _mk),
    ];
    if (!more) _shown.clear();
    final res = CouponEngine.generate(cands, _c, exclude: _shown);
    _shown.addAll(res.map((c) => c.signature));
    Analytics.log('coupon_generate', {'preset': _preset, 'period': _c.period, 'found': res.length});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = res;
      _analyzed = matches.length + (usePool ? pool.length : 0);
      _msg = res.isNotEmpty
          ? null
          : cands.length < _c.countMin
              ? "Pas assez de matchs à venir pour ces critères. Élargis la cote ou la probabilité par match, ou choisis « Les deux » jours."
              : more
                  ? "Plus d'autres combinaisons pour ces critères. Modifie-les pour en découvrir de nouvelles."
                  : "Aucune combinaison ne respecte ces critères. Élargis la cote totale ou le nombre de matchs.";
    });
  }

  Future<void> _save(Coupon c) async {
    final r = await CouponStore.add(c);
    Analytics.log('coupon_save', {'result': r});
    final l = await CouponStore.all();
    if (mounted) setState(() => _saved = l);
    _snack(r == 'ok'
        ? '⭐ Coupon enregistré dans « Mes coupons »'
        : r == 'full'
            ? 'Limite de 5 coupons atteinte : supprime un coupon pour en enregistrer un nouveau.'
            : 'Ce coupon est déjà enregistré');
  }

  Future<void> _delete(Coupon c) async {
    await CouponStore.remove(c);
    final l = await CouponStore.all();
    if (mounted) setState(() => _saved = l);
    _snack('Coupon supprimé');
  }

  void _open(Leg l) {
    final m = _byId[l.matchId];
    if (m == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PtMatchScreen(match: m)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 96),
      children: [
        _viewSwitch(),
        SizedBox(height: 12),
        if (_view == 0) ..._create() else ..._mine(),
      ],
    );
  }

  Widget _viewSwitch() {
    Widget half(String label, int v) {
      final sel = _view == v;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _view = v);
            if (v == 1) _loadSaved();
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? K.indigoSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: T(label,
                style: TextStyle(color: sel ? K.text : K.muted, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3),
      decoration: kBox(r: 12),
      child: Row(children: [half('Créer un coupon', 0), half('Mes coupons · ${_saved.length}', 1)]),
    );
  }

  Widget _hero() => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T('Créateur de coupons',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              T(
                kV2 ? 'Fixe tes critères : KOUNADIA analyse les matchs à venir et compose les meilleurs coupons.' : 'Fixe tes critères : KOUNADIA IA analyse les matchs à venir et compose les meilleurs coupons.',
                style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13, height: 1.35),
              ),
            ]),
          ),
        ]),
      );

  Widget _seg(List<String> labels, int sel, ValueChanged<int> on) => Container(
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => on(i),
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == sel ? K.indigo : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: T(labels[i],
                      style: TextStyle(
                          color: i == sel ? Colors.white : K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      );

  Widget _head(String title, String value) => Padding(
        padding: EdgeInsets.fromLTRB(2, 14, 2, 0),
        child: Row(children: [
          Expanded(
            child: T(title, style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          T(value, style: TextStyle(color: K.indigoText, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _slider(RangeValues v, double min, double max, int div, ValueChanged<RangeValues> on) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: K.indigo,
          inactiveTrackColor: K.border,
          thumbColor: Colors.white,
          overlayColor: K.indigo.withAlpha(40),
          trackHeight: 4,
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: RangeSlider(values: v, min: min, max: max, divisions: div, onChanged: on),
      );

  Widget _toggle(String label, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? K.indigoSoft : K.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? K.indigoText : K.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(on ? Icons.check_rounded : Icons.add_rounded, size: 15, color: on ? K.text : K.muted),
            SizedBox(width: 4),
            T(label,
                style: TextStyle(color: on ? K.text : K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  void _edit(VoidCallback f) => setState(() {
        f();
        _preset = '';
      });

  Widget _criteria() => Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: kBox(r: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('Période', style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          _seg(["Aujourd'hui", 'Demain', 'Les deux'], _c.period, (i) => setState(() => _c.period = i)),
          _head('Cote totale', '×${fx(_c.totalMin)} – ×${fx(_c.totalMax)}'),
          _slider(RangeValues(_fromOdd(_c.totalMin), _fromOdd(_c.totalMax)), 0, 1, 60,
              (v) => _edit(() {
                    _c.totalMin = _r(_toOdd(v.start));
                    _c.totalMax = _r(_toOdd(v.end));
                  })),
          _head('Nombre de matchs', '${_c.countMin} – ${_c.countMax}'),
          _slider(RangeValues(_c.countMin.toDouble(), _c.countMax.toDouble()), 2, 12, 10,
              (v) => _edit(() {
                    _c.countMin = v.start.round();
                    _c.countMax = v.end.round();
                  })),
          InkWell(
            onTap: () => setState(() => _advanced = !_advanced),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.tune_rounded, color: K.muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: T('Critères avancés',
                      style: TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                Icon(_advanced ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
              ]),
            ),
          ),
          if (_advanced) ...[
            _head('Cote par match', '${fx(_c.oddMin)} – ${fx(_c.oddMax)}'),
            _slider(RangeValues(_c.oddMin, _c.oddMax), 1.10, 4.00, 58,
                (v) => _edit(() {
                      _c.oddMin = (v.start * 100).round() / 100;
                      _c.oddMax = (v.end * 100).round() / 100;
                    })),
            _head('Probabilité par match', '${_c.probMin} % – ${_c.probMax} %'),
            _slider(RangeValues(_c.probMin.toDouble(), _c.probMax.toDouble()), 30, 95, 13,
                (v) => _edit(() {
                      _c.probMin = v.start.round();
                      _c.probMax = v.end.round();
                    })),
            SizedBox(height: 6),
            T('Types de paris',
                style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _toggle('Victoire', _c.win, () {
                if (_c.win && !_c.draw && !_c.dc) return;
                _edit(() => _c.win = !_c.win);
              }),
              _toggle('Match nul', _c.draw, () {
                if (_c.draw && !_c.win && !_c.dc) return;
                _edit(() => _c.draw = !_c.draw);
              }),
              _toggle('Plus/Moins de buts', _c.goals, () => _edit(() => _c.goals = !_c.goals)),
              _toggle('Les deux marquent', _c.btts, () => _edit(() => _c.btts = !_c.btts)),
              _toggle('Double chance', _c.dc, () {
                if (_c.dc && !_c.win && !_c.draw) return;
                _edit(() => _c.dc = !_c.dc);
              }),
              _toggle("Buts d'une équipe", _c.team, () => _edit(() => _c.team = !_c.team)),
              _toggle('Mi-temps', _c.half, () => _edit(() => _c.half = !_c.half)),
              _toggle('Corners, fautes, tirs', _c.stats, () => _edit(() => _c.stats = !_c.stats)),
            ]),
            SizedBox(height: 8),
          ],
        ]),
      );

  Widget _note(String t) => Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color(0x22F59E0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0x55F59E0B)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: K.amber, size: 18),
          SizedBox(width: 10),
          Expanded(child: T(t, style: TextStyle(color: K.text, fontSize: 13, height: 1.4))),
        ]),
      );

  List<Widget> _create() => [
        _hero(),
        SizedBox(height: 12),
        Row(children: [
          for (final (k, label) in [('safe', 'Prudent'), ('eq', 'Équilibré'), ('bold', 'Audacieux')])
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: kPill(label, _preset == k, () => _applyPreset(k)),
              ),
            ),
        ]),
        SizedBox(height: 12),
        _criteria(),
        SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _generate(),
            style: FilledButton.styleFrom(
              backgroundColor: K.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _busy
                ? SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.auto_awesome_rounded),
            label: T(_busy ? 'Analyse en cours…' : 'Générer mes coupons',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        SizedBox(height: 14),
        KndBanner(),
        if (_msg != null) _note(_msg!),
        if (_results.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: T(
              '${_results.length} coupon${_results.length > 1 ? 's' : ''} proposé${_results.length > 1 ? 's' : ''} · $_analyzed matchs analysés',
              style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          for (var i = 0; i < _results.length; i++) ...[
            _CouponCard(
              coupon: _results[i],
              title: 'Coupon ${i + 1}',
              saved: false,
              onShare: () => shareCoupon(context, _results[i]),
              onAction: () => _save(_results[i]),
              onOpen: _open,
            ),
            SizedBox(height: 12),
          ],
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _generate(more: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: K.text,
                side: BorderSide(color: K.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(Icons.refresh_rounded),
              label: T("Générer d'autres coupons", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        SizedBox(height: 16),
        T(
          "Cotes moyennes indicatives : elles peuvent varier chez le bookmaker. Aucun coupon n'est garanti. 18+ · Jouez de manière responsable.",
          textAlign: TextAlign.center,
          style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4),
        ),
      ];

  List<Widget> _mine() {
    if (_saved.isEmpty) {
      return [
        KndBanner(),
        SizedBox(height: 30),
        kMessage('Aucun coupon enregistré.\nGénère un coupon puis appuie sur ☆ pour le retrouver ici.'),
      ];
    }
    return [
      Row(children: [
        Expanded(
          child: T('${_saved.length} coupon${_saved.length > 1 ? 's' : ''} enregistré${_saved.length > 1 ? 's' : ''}',
              style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        TextButton.icon(
          onPressed: _loadSaved,
          icon: Icon(Icons.sync_rounded, size: 18, color: K.indigoText),
          label: T('Actualiser', style: TextStyle(color: K.indigoText, fontWeight: FontWeight.w700)),
        ),
      ]),
      KndBanner(),
      for (final c in _saved) ...[
        _CouponCard(
          coupon: c,
          title: 'Créé le ${two(c.created.day)}/${two(c.created.month)} à ${hm(c.created)}',
          saved: true,
          onShare: () => shareCoupon(context, c),
          onAction: () => _delete(c),
          onOpen: _open,
        ),
        SizedBox(height: 12),
      ],
    ];
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final String title;
  final bool saved;
  final VoidCallback onShare;
  final VoidCallback onAction;
  final void Function(Leg) onOpen;

  _CouponCard({
    required this.coupon,
    required this.title,
    required this.saved,
    required this.onShare,
    required this.onAction,
    required this.onOpen,
  });

  Widget _leg(Leg l) {
    final rc = l.result == 'won'
        ? K.green
        : l.result == 'lost'
            ? K.red
            : l.result == 'live'
                ? K.amber
                : K.muted;
    final d = l.date;
    return InkWell(
      onTap: () => onOpen(l),
      child: Container(
      color: (l.result == 'won' || l.result == 'lost') ? rc.withAlpha(30) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          SizedBox(
            width: 46,
            child: Column(children: [
              T(d == null ? '--:--' : hm(d),
                  style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              T(d == null ? '' : '${two(d.day)}/${two(d.month)}',
                  style: TextStyle(color: K.muted, fontSize: 10.5)),
              if (l.result != 'pending')
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    l.result == 'won'
                        ? Icons.check_circle_rounded
                        : l.result == 'lost'
                            ? Icons.cancel_rounded
                            : l.result == 'void'
                                ? Icons.remove_circle_outline_rounded
                                : Icons.radio_button_checked_rounded,
                    color: rc,
                    size: 15,
                  ),
                ),
            ]),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T(l.league,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 11)),
              SizedBox(height: 2),
              T('${l.home} – ${l.away}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
              SizedBox(height: 3),
              T(l.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: l.result == 'won' || l.result == 'lost' ? rc : K.indigoText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              if (l.score != null)
                Text(l.score!.replaceAll('-', ' - '), style: TextStyle(color: rc, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          ),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            T('${l.est ? '≈' : '@'}${fx(l.odd)}', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
            T('${l.prob} %', style: TextStyle(color: K.muted, fontSize: 11.5)),
          ]),
        ]),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (stLabel, stColor) = switch (coupon.status) {
      'won' => ('Gagné', K.green),
      'lost' => ('Perdu', K.red),
      'live' => ('En cours', K.amber),
      _ => ('En attente', K.indigoText),
    };
    final rows = <Widget>[];
    for (var i = 0; i < coupon.legs.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: K.border));
      rows.add(_leg(coupon.legs[i]));
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: kBox(r: 16),
      child: Column(children: [
        Container(
          color: K.groupHead,
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T(title, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Row(children: [
                  T('${coupon.legs.length} matchs', style: TextStyle(color: K.muted, fontSize: 12)),
                  if (saved) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: stColor.withAlpha(45), borderRadius: BorderRadius.circular(10)),
                      child: T(stLabel, style: TextStyle(color: stColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              T('${coupon.x}${fx(coupon.total)}',
                  style: TextStyle(color: K.green, fontSize: 22, fontWeight: FontWeight.w900)),
              T('cote totale', style: TextStyle(color: K.muted, fontSize: 11)),
            ]),
          ]),
        ),
        ...rows,
        Container(height: 1, color: K.border),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 2, 4, 2),
          child: Row(children: [
            Icon(Icons.insights_rounded, color: K.muted, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: T('${tr('Probabilité estimée')} ≈ ${coupon.pctText()}',
                  style: TextStyle(color: K.muted, fontSize: 12.5)),
            ),
            IconButton(
              tooltip: tr('Partager'),
              onPressed: onShare,
              icon: Icon(Icons.share_rounded, color: K.muted, size: 20),
            ),
            IconButton(
              tooltip: tr(saved ? 'Supprimer' : 'Enregistrer'),
              onPressed: onAction,
              icon: Icon(saved ? Icons.delete_outline_rounded : Icons.star_border_rounded,
                  color: saved ? K.red : K.amber, size: 22),
            ),
          ]),
        ),
      ]),
    );
  }
}
